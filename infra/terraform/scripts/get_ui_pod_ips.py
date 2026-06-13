import subprocess
import json
import sys

def main():
    context = sys.argv[1] if len(sys.argv) > 1 else ""
    namespace = sys.argv[2] if len(sys.argv) > 2 else "retail-store-sample-test"
    service_name = sys.argv[3] if len(sys.argv) > 3 else "ui"

    cmd = ["kubectl", "get", "endpoints", service_name, "-n", namespace]
    if context:
        cmd.extend(["--context", context])
    cmd.extend(["-o", "jsonpath={.subsets[0].addresses[*].ip}"])

    try:
        res = subprocess.run(cmd, capture_output=True, text=True, check=True)
        ips = res.stdout.strip()
        print(json.dumps({"ips": ips}))
    except Exception:
        # Return empty string JSON if the namespace, service, or cluster is not available
        print(json.dumps({"ips": ""}))

if __name__ == "__main__":
    main()
