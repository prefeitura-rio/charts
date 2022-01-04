from os import getenv, getpid, kill
from queue import Queue, Empty
import signal
import subprocess
import sys
from threading import Thread
from time import sleep


class CustomThread(Thread):
    """
    Allows us to kill threads and get exceptions from them.
    Adapted from:
        - https://www.geeksforgeeks.org/python-different-ways-to-kill-a-thread/
        - https://stackoverflow.com/questions/2829329/catch-a-threads-exception-in-the-caller-thread
    """

    def __init__(self, bucket: Queue, *args, **keywords):
        super().__init__(*args, **keywords)
        self.killed = False
        self.bucket = bucket

    def start(self):
        self.__run_backup = self.run
        self.run = self.__run
        Thread.start(self)

    def __run(self):
        sys.settrace(self.globaltrace)
        self.__run_backup()
        self.run = self.__run_backup

    def run(self):
        try:
            super().run()
        except Exception:
            self.bucket.put(sys.exc_info())

    def globaltrace(self, frame, event, arg):
        if event == 'call':
            return self.localtrace
        else:
            return None

    def localtrace(self, frame, event, arg):
        if self.killed:
            raise SystemExit()
        return self.localtrace

    def kill(self):
        self.killed = True


def print_no_newline(text: str, prefix=None) -> None:
    if prefix:
        print(f"[{prefix}] {text}", end="")
    else:
        print(text, end="")


def run_shell_command(command: str, prefix: str = None) -> int:
    print(f"\n[{prefix}] Running command: {command}")
    popen = subprocess.Popen(
        command, shell=True, stdout=subprocess.PIPE, universal_newlines=True)
    for stdout_line in iter(popen.stdout.readline, ""):
        print_no_newline(stdout_line, prefix=prefix)
    popen.stdout.close()
    return_code = popen.wait()
    if return_code:
        raise subprocess.CalledProcessError(return_code, command)
    return return_code


def run_threaded(command: str, bucket: Queue, prefix: str = None) -> CustomThread:
    thread = CustomThread(target=run_shell_command,
                          args=(command, prefix), bucket=bucket)
    thread.start()
    return thread


if __name__ == "__main__":
    if getenv("TAILSCALE_AUTHKEY") is None:
        print_no_newline("TAILSCALE_AUTHKEY not set\n", "ERROR")
        exit(1)

    bucket = Queue()
    sleep(1)

    thread_tailscale = run_threaded(
        f"tailscale up --accept-routes --accept-dns --authkey {getenv('TAILSCALE_AUTHKEY')}",
        prefix="TAILSCALE",
        bucket=bucket,
    )

    sleep(5)

    cmd = "prefect agent kubernetes start"
    job_template_filepath = getenv("JOB_TEMPLATE_FILEPATH")
    cmd_args = f"--job-template {job_template_filepath}" if job_template_filepath else ""
    thread_prefect = run_threaded(
        f"{cmd} {cmd_args}",
        prefix="PREFECT",
        bucket=bucket,
    )

    while True:
        sleep(1)
        try:
            exc_info = bucket.get(block=False)
        except Empty:
            continue
        else:
            print_no_newline("\n", "ERROR")
            print_no_newline(
                f"{exc_info[0].__name__}: {exc_info[1]}\n", "ERROR")
            print_no_newline(f"{exc_info[2]}\n", "ERROR")
            print_no_newline("\n", "ERROR")
            thread_prefect.kill()
            print("Killed prefect")
            thread_tailscale.kill()
            print("Killed tailscale")
            sys.exit(1)
