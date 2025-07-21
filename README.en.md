<!-- TOC -->

- [Background](#background)
- [Issues with Ray Distributed Debugger in Kuberay Environment](#issues-with-ray-distributed-debugger-in-kuberay-environment)
- [Technical Exploration](#technical-exploration)
    - [Request Proxy Approach: Exploration and Limitations](#request-proxy-approach-exploration-and-limitations)
    - [Code-Server: A Browser-Based VSCode Solution](#code-server-a-browser-based-vscode-solution)
- [Deployment Example](#deployment-example)
    - [Development Environment Options](#development-environment-options)
    - [Deployment Steps](#deployment-steps)
- [Conclusion and Reflections](#conclusion-and-reflections)

<!-- /TOC -->

# Background

In software development, debuggers with step-by-step capabilities are crucial tools for improving development efficiency. For complex distributed systems, step-by-step debugging is particularly important as it helps developers quickly locate issues within intricate synchronous/asynchronous code paths, thereby shortening problem diagnosis cycles.

Taking distributed storage systems as an example, in 2021, I configured step-by-step debugging capabilities for Apache IoTDB 3C3D clusters through IDEA (refer to my [blog](https://tanxinyu.work/cluster-iotdb-idea-debugger/)). In the following years, this approach helped me solve numerous challenging issues in IoTDB distributed development, enhancing development efficiency.

Recently, I began learning and researching the Ray distributed computing framework, starting with its debugging functionality. Ray officially supports two types of debuggers, with specific usage instructions available in the official documentation. Here's a brief introduction:
* [Ray Debugger](https://docs.ray.io/en/latest/ray-observability/user-guides/debug-apps/ray-debugging.html): Performs step-by-step debugging through the Ray debug command, reusing the pdb session command line. It has been marked as deprecated since version 2.39 and is not recommended for use.
* [Ray Distributed Debugger](https://docs.ray.io/en/latest/ray-observability/ray-distributed-debugger.html): Performs step-by-step debugging through a VSCode plugin, reusing the pydebug graphical interface for a better experience. It is currently the default debugging tool recommended by the Ray community.

> Note: Ray Cluster must be configured with the appropriate Debugger parameters at startup, and the two Debugger types cannot be used simultaneously.

The core principle of Ray Distributed Debugger is based on the RAY_DEBUG environment variable that is enabled by default in the Ray kernel. When a breakpoint is triggered, all Workers periodically aggregate breakpoint information to the Head node. The VSCode plugin connects to the Ray Head node to retrieve the breakpoint list, allowing users to click Start Debugging to attach to the corresponding Worker for step-by-step debugging. The official documentation outline is as follows:

<div align="center">
<img src="https://private-user-images.githubusercontent.com/32640567/471828146-a95749ad-d3a9-44b5-a3ab-1029a424e000.png?jwt=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3NTM3ODExOTgsIm5iZiI6MTc1Mzc4MDg5OCwicGF0aCI6Ii8zMjY0MDU2Ny80NzE4MjgxNDYtYTk1NzQ5YWQtZDNhOS00NGI1LWEzYWItMTAyOWE0MjRlMDAwLnBuZz9YLUFtei1BbGdvcml0aG09QVdTNC1ITUFDLVNIQTI1NiZYLUFtei1DcmVkZW50aWFsPUFLSUFWQ09EWUxTQTUzUFFLNFpBJTJGMjAyNTA3MjklMkZ1cy1lYXN0LTElMkZzMyUyRmF3czRfcmVxdWVzdCZYLUFtei1EYXRlPTIwMjUwNzI5VDA5MjEzOFomWC1BbXotRXhwaXJlcz0zMDAmWC1BbXotU2lnbmF0dXJlPWFhY2JlZGFlYTQxMzU0MGFjZGQ3M2JlZjQwYjUyYTI1OGJkY2U4MmRiNDg5YTYwYjc3NGI3YWI4ZTZkZDc5M2QmWC1BbXotU2lnbmVkSGVhZGVycz1ob3N0In0.EjIeqNNtMEwSFZtVY8tFimng4-HkUUVT8oOfPKzCexI" width="100%" alt="Ray Distributed Debugger Architecture">
</div>

# Issues with Ray Distributed Debugger in Kuberay Environment

As mentioned above, Ray Distributed Debugger needs network connectivity to the Worker that triggers the breakpoint to implement step-by-step debugging. In bare-metal deployment scenarios, this requirement can be met by simply configuring firewall rules. However, with the popularization of cloud-native technologies, most distributed computing frameworks now utilize Kubernetes (K8S) for resource management. In such cases, users typically choose to install [Kuberay](https://github.com/ray-project/kuberay) and control the Ray cluster's lifecycle and resources through custom resources like RayCluster/RayJob/RayServe.

In a K8S environment, due to its network isolation mechanism, the Ray cluster actually runs in an isolated network space inside the cluster, and external entities cannot directly access the various components of the Ray Cluster by default. Ray Distributed Debugger needs to connect to the dashboard port (8265) of the Ray Head node to obtain all breakpoint information. In this case, we can expose port 8265 of the Ray Head to allow Ray Distributed Debugger to access the list of breakpoints triggered in the cluster.

Here's an example of testing Ray Distributed Debugger in a Kuberay environment:

1. First, install the K8S cluster and kuberay-operator, then submit a job that will trigger a breakpoint using the RayJob mode.

<div align="center">
<img src="https://private-user-images.githubusercontent.com/32640567/471839239-d684fa2c-c2bf-44cb-a393-4c6bbd66edd9.png?jwt=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3NTM3NzAwMzEsIm5iZiI6MTc1Mzc2OTczMSwicGF0aCI6Ii8zMjY0MDU2Ny80NzE4MzkyMzktZDY4NGZhMmMtYzJiZi00NGNiLWEzOTMtNGM2YmJkNjZlZGQ5LnBuZz9YLUFtei1BbGdvcml0aG09QVdTNC1ITUFDLVNIQTI1NiZYLUFtei1DcmVkZW50aWFsPUFLSUFWQ09EWUxTQTUzUFFLNFpBJTJGMjAyNTA3MjklMkZ1cy1lYXN0LTElMkZzMyUyRmF3czRfcmVxdWVzdCZYLUFtei1EYXRlPTIwMjUwNzI5VDA2MTUzMVomWC1BbXotRXhwaXJlcz0zMDAmWC1BbXotU2lnbmF0dXJlPTYwNDRmYTgwYjE0YWNhZWU1ZDYzZDdlMTI4MmM0Y2M2NTI0ZTQ5NDE0ZDM1ODJhYjQxOTIyYzY0ODk4MDU2ZmMmWC1BbXotU2lnbmVkSGVhZGVycz1ob3N0In0.6SZ0uNzpCYkhDQcj0hFI2WeiWmKa79RRErbtIWEskXA" width="100%" alt="Submit RayJob with breakpoint">
</div>

2. When a breakpoint is triggered in the code, a log will be printed on the job submitter side, indicating that the debugger is waiting for attachment:

<div align="center">
<img src="https://private-user-images.githubusercontent.com/32640567/471838778-f68bafa5-551e-436e-aab8-750d6b50dd2c.png?jwt=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3NTM3Njk5NDYsIm5iZiI6MTc1Mzc2OTY0NiwicGF0aCI6Ii8zMjY0MDU2Ny80NzE4Mzg3NzgtZjY4YmFmYTUtNTUxZS00MzZlLWFhYjgtNzUwZDZiNTBkZDJjLnBuZz9YLUFtei1BbGdvcml0aG09QVdTNC1ITUFDLVNIQTI1NiZYLUFtei1DcmVkZW50aWFsPUFLSUFWQ09EWUxTQTUzUFFLNFpBJTJGMjAyNTA3MjklMkZ1cy1lYXN0LTElMkZzMyUyRmF3czRfcmVxdWVzdCZYLUFtei1EYXRlPTIwMjUwNzI5VDA2MTQwNlomWC1BbXotRXhwaXJlcz0zMDAmWC1BbXotU2lnbmF0dXJlPTBiMzVhODkzZWU0ODUzNDJkNzk3NjQ0Y2I0MTBlMmM0M2RmMjZmNzk1ZTZhMTIzNDI4NThmYmY3M2QwYTFmNzImWC1BbXotU2lnbmVkSGVhZGVycz1ob3N0In0.gjo_fKoohiZnABmr2uV3ryfD7QSjFj345_4y2ULP9-U" width="100%" alt="Debugger waiting for attach">
</div>

3. We use the `kubectl port-forward` command to forward port 8265 of the Head node to local port 8265, and connect via Ray Distributed Debugger. At this point, we can see all breakpoints triggered in the cluster:

<div align="center">
<img src="https://private-user-images.githubusercontent.com/32640567/471837925-fcc354c9-a2e6-4e1a-8703-28eca532ff2f.png?jwt=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3NTM3Njk3OTgsIm5iZiI6MTc1Mzc2OTQ5OCwicGF0aCI6Ii8zMjY0MDU2Ny80NzE4Mzc5MjUtZmNjMzU0YzktYTJlNi00ZTFhLTg3MDMtMjhlY2E1MzJmZjJmLnBuZz9YLUFtei1BbGdvcml0aG09QVdTNC1ITUFDLVNIQTI1NiZYLUFtei1DcmVkZW50aWFsPUFLSUFWQ09EWUxTQTUzUFFLNFpBJTJGMjAyNTA3MjklMkZ1cy1lYXN0LTElMkZzMyUyRmF3czRfcmVxdWVzdCZYLUFtei1EYXRlPTIwMjUwNzI5VDA2MTEzOFomWC1BbXotRXhwaXJlcz0zMDAmWC1BbXotU2lnbmF0dXJlPWVjOWQzMGI3MTY2OThjNTljYjZmOWMwZWNmNjE3YzE5ZDI1YjBlNzczYzJkZjdlNTNjOTU5ZWU0MjZjYzUxNDgmWC1BbXotU2lnbmVkSGVhZGVycz1ob3N0In0.XGAbbzl7_K8KMPSxCofMCnepS3A9pmGz0RvN_oouYpc" width="100%" alt="Ray Distributed Debugger showing breakpoints">
</div>

4. However, when attempting to connect to any breakpoint for debugging, the system shows that it cannot attach to the breakpoint, with the following error:

<div align="center">
<img src="https://private-user-images.githubusercontent.com/32640567/471838614-911ff170-587c-4923-9afb-29e0ebcea1a4.png?jwt=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3NTM3Njk5NDAsIm5iZiI6MTc1Mzc2OTY0MCwicGF0aCI6Ii8zMjY0MDU2Ny80NzE4Mzg2MTQtOTExZmYxNzAtNTg3Yy00OTIzLTlhZmItMjllMGViY2VhMWE0LnBuZz9YLUFtei1BbGdvcml0aG09QVdTNC1ITUFDLVNIQTI1NiZYLUFtei1DcmVkZW50aWFsPUFLSUFWQ09EWUxTQTUzUFFLNFpBJTJGMjAyNTA3MjklMkZ1cy1lYXN0LTElMkZzMyUyRmF3czRfcmVxdWVzdCZYLUFtei1EYXRlPTIwMjUwNzI5VDA2MTQwMFomWC1BbXotRXhwaXJlcz0zMDAmWC1BbXotU2lnbmF0dXJlPTFmZThjZTZlNzViZjA0MGNhYmJmMDM4ZmM3OGYzMjM5ZWZlM2VlMjBkYTU0ODQ5ZDY3NjYwMTk1ZmMyNmM5NmYmWC1BbXotU2lnbmVkSGVhZGVycz1ob3N0In0.6BEfMIj5v4A6TBCHxJUqu9eXGHE_EjxADI4GByDS8bM" width="100%" alt="Connection error to breakpoint">
</div>


5. After analyzing the error message, we found that the problem is that the Ray Distributed Debugger plugin is trying to connect to IP addresses and ports internal to the Kubernetes cluster. These IPs and ports cannot be directly accessed from outside the cluster, and the ports are randomly assigned, making it impossible to map them in advance. This leads to connection failures.

The above example shows that there are practical difficulties in using Ray Distributed Debugger in a Kuberay environment.

It's worth mentioning that in the official documentation, we also found a [PR](https://github.com/ray-project/ray/pull/49116) that proposed a solution involving installing SSH in the Ray Head image and connecting via VSCode Remote. While theoretically feasible, this approach is criticized by users for being complex, involving key management, lifecycle management, and other issues.

<div align="center">
<img src="https://private-user-images.githubusercontent.com/32640567/471862147-4c71db82-1c47-480f-9a68-955aa7fc32c8.png?jwt=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3NTM3NzM5MzgsIm5iZiI6MTc1Mzc3MzYzOCwicGF0aCI6Ii8zMjY0MDU2Ny80NzE4NjIxNDctNGM3MWRiODItMWM0Ny00ODBmLTlhNjgtOTU1YWE3ZmMzMmM4LnBuZz9YLUFtei1BbGdvcml0aG09QVdTNC1ITUFDLVNIQTI1NiZYLUFtei1DcmVkZW50aWFsPUFLSUFWQ09EWUxTQTUzUFFLNFpBJTJGMjAyNTA3MjklMkZ1cy1lYXN0LTElMkZzMyUyRmF3czRfcmVxdWVzdCZYLUFtei1EYXRlPTIwMjUwNzI5VDA3MjAzOFomWC1BbXotRXhwaXJlcz0zMDAmWC1BbXotU2lnbmF0dXJlPTFkZjVkOTc0ZDU1ZmY3MGUyNjM0Yjk3ZTBhYzNjZjNhMWJjYjk3NjBkMTM5OGQ0MzY0MzUwY2JiNGE5OGVlNDQmWC1BbXotU2lnbmVkSGVhZGVycz1ob3N0In0.xTR1-GW41zljxUAB3HEAsz-tuPa5oKR9NZBUtrCbS7g" width="100%" alt="User complaint about SSH approach">
</div>

<div align="center">
<img src="https://private-user-images.githubusercontent.com/32640567/471864120-cddf7683-de6b-4533-b994-7a844d0fe676.png?jwt=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3NTM3NzM5NjgsIm5iZiI6MTc1Mzc3MzY2OCwicGF0aCI6Ii8zMjY0MDU2Ny80NzE4NjQxMjAtY2RkZjc2ODMtZGU2Yi00NTMzLWI5OTQtN2E4NDRkMGZlNjc2LnBuZz9YLUFtei1BbGdvcml0aG09QVdTNC1ITUFDLVNIQTI1NiZYLUFtei1DcmVkZW50aWFsPUFLSUFWQ09EWUxTQTUzUFFLNFpBJTJGMjAyNTA3MjklMkZ1cy1lYXN0LTElMkZzMyUyRmF3czRfcmVxdWVzdCZYLUFtei1EYXRlPTIwMjUwNzI5VDA3MjEwOFomWC1BbXotRXhwaXJlcz0zMDAmWC1BbXotU2lnbmF0dXJlPTEzYjMzYTM0YWNjODFhODEzMmQ1NzQzODRhZjNhMTU2YjRhZWFmNDBhNjhjNzhkYmMxOTVhZWI4YzdlNDgxNDYmWC1BbXotU2lnbmVkSGVhZGVycz1ob3N0In0.h4WZ0d4BUeFg-HHNitgqzc5t22xSiQGQg1naQl-OpSk" width="100%" alt="More complaints about SSH approach">
</div>

Through analysis, we found that Ray's official support for Ray Distributed Debugger in Kuberay environments is not sufficiently robust, necessitating a more convenient solution.

# Technical Exploration

Is there a convenient way to use Ray Distributed Debugger in a Kubernetes environment? With this question in mind, I conducted some technical research and experimentation.

## Request Proxy Approach: Exploration and Limitations

First, I consulted the relevant issue in the Ray official GitHub repository: [[Ray debugger] Unable to use debugger on Ray Cluster on k8s](https://github.com/ray-project/ray/issues/45541). From the discussion, it's clear that Ray's initial solution was to have Workers use a fixed port range when exposing ports for attachment, allowing users to pre-expose these ports externally for attachment:

<div align="center">
<img src="https://private-user-images.githubusercontent.com/32640567/471845733-0882850e-b796-4e7d-a1cf-875584e68b02.png?jwt=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3NTM3NzExOTEsIm5iZiI6MTc1Mzc3MDg5MSwicGF0aCI6Ii8zMjY0MDU2Ny80NzE4NDU3MzMtMDg4Mjg1MGUtYjc5Ni00ZTdkLWExY2YtODc1NTg0ZTY4YjAyLnBuZz9YLUFtei1BbGdvcml0aG09QVdTNC1ITUFDLVNIQTI1NiZYLUFtei1DcmVkZW50aWFsPUFLSUFWQ09EWUxTQTUzUFFLNFpBJTJGMjAyNTA3MjklMkZ1cy1lYXN0LTElMkZzMyUyRmF3czRfcmVxdWVzdCZYLUFtei1EYXRlPTIwMjUwNzI5VDA2MzQ1MVomWC1BbXotRXhwaXJlcz0zMDAmWC1BbXotU2lnbmF0dXJlPWVjMjI1YTU1OTM3YjU2MTIwNTM5NmQ2MzRjMDIxZjI2ZTEyNmU5YWQxNGM4YjVlNTU0OTI0M2FhZWYyZTg5OWImWC1BbXotU2lnbmVkSGVhZGVycz1ob3N0In0.RETvE1SZUih3iuMZ7zUJF6mTgV6gKkiG9X97H54zimk" width="100%" alt="GitHub issue discussion about port ranges">
</div>

Some developers even submitted related PRs attempting to integrate this functionality into the Ray kernel, but the PR was ultimately not progressed and was automatically closed:

<div align="center">
<img src="https://private-user-images.githubusercontent.com/32640567/471848415-e2cbfc19-9f5c-4e25-b6e2-c96ac4b1d1ef.png?jwt=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3NTM3NzE1NDQsIm5iZiI6MTc1Mzc3MTI0NCwicGF0aCI6Ii8zMjY0MDU2Ny80NzE4NDg0MTUtZTJjYmZjMTktOWY1Yy00ZTI1LWI2ZTItYzk2YWM0YjFkMWVmLnBuZz9YLUFtei1BbGdvcml0aG09QVdTNC1ITUFDLVNIQTI1NiZYLUFtei1DcmVkZW50aWFsPUFLSUFWQ09EWUxTQTUzUFFLNFpBJTJGMjAyNTA3MjklMkZ1cy1lYXN0LTElMkZzMyUyRmF3czRfcmVxdWVzdCZYLUFtei1EYXRlPTIwMjUwNzI5VDA2NDA0NFomWC1BbXotRXhwaXJlcz0zMDAmWC1BbXotU2lnbmF0dXJlPTVjM2NjNDg3NzdiMjJiNWY4ZmY5YTA1ZTFlYTZiZTkxNGRmNGQ5YWI0MTBiOWQ0ZDY0NDYxYTNiZWY4ZDIyZDAmWC1BbXotU2lnbmVkSGVhZGVycz1ob3N0In0.N3Zgz5OloUdvbXitTPEfJSckkhmWsvjLiG0IMBGaLXM" width="100%" alt="Closed PR for port range feature">
</div>

I speculate that this approach did not progress primarily because of several obvious issues:

1. **Port Range Setting Challenge**: How to determine an appropriate port range? Too small a range might not cover all breakpoints, while too large a range might occupy too many cluster resources or even conflict with ports of system components like the Kubernetes API Server.

2. **High Operational Complexity**: Even with a defined port range, users would still need to manually expose numerous ports, a process that is cumbersome and error-prone, contradicting the automated design philosophy of cloud-native environments.

3. **Network Connection Barriers**: Most critically, even if ports are successfully exposed, the Ray Distributed Debugger VSCode plugin would still attempt to connect to IP addresses internal to the Kubernetes cluster, which are not reachable from outside. Since the VSCode plugin is now closed-source and managed by Anyscale, we cannot modify its connection logic.

In theory, one could set up `kubectl port-forward` for each breakpoint and combine it with iptables rules to redirect local requests to Kubernetes internal IPs to the corresponding local ports. However, this method is cumbersome, difficult to automate, requires deep networking knowledge, and is almost unmaintainable when dealing with numerous breakpoints.

Considering these factors, especially the fundamental limitation in point three, I abandoned this technical path and sought a simpler solution.

## Code-Server: A Browser-Based VSCode Solution

At the end of the aforementioned issue discussion, a user reported successfully solving the problem by deploying Code Server in their Kubernetes cluster:

<div align="center">
<img src="https://private-user-images.githubusercontent.com/32640567/471860720-1aae8795-e958-4b14-aa8f-9833137c36bd.png?jwt=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3NTM3NzM0ODQsIm5iZiI6MTc1Mzc3MzE4NCwicGF0aCI6Ii8zMjY0MDU2Ny80NzE4NjA3MjAtMWFhZTg3OTUtZTk1OC00YjE0LWFhOGYtOTgzMzEzN2MzNmJkLnBuZz9YLUFtei1BbGdvcml0aG09QVdTNC1ITUFDLVNIQTI1NiZYLUFtei1DcmVkZW50aWFsPUFLSUFWQ09EWUxTQTUzUFFLNFpBJTJGMjAyNTA3MjklMkZ1cy1lYXN0LTElMkZzMyUyRmF3czRfcmVxdWVzdCZYLUFtei1EYXRlPTIwMjUwNzI5VDA3MTMwNFomWC1BbXotRXhwaXJlcz0zMDAmWC1BbXotU2lnbmF0dXJlPWFmZTUyZjQxMzViODk1OTM1OGZkMWU1OWIzZjEwOGQ4YWUzNWI2ZWJkYjQzNjUzYmRlNTNkY2Y0MzBhYmI3ZDUmWC1BbXotU2lnbmVkSGVhZGVycz1ob3N0In0.KtKDlcpxLdHQ091NHMVDYxQSgC0VRNkMw2yaULKgnIs" width="100%" alt="User suggesting Code Server solution">
</div>

This approach was acknowledged by the Ray team, but due to the lack of specific implementation details and a complete solution, the approach remained at a conceptual stage:

<div align="center">
<img src="https://private-user-images.githubusercontent.com/32640567/471860979-d6c7bf40-1fbf-4bf6-9d24-b95a80cf3f9e.png?jwt=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3NTM3NzQyNjYsIm5iZiI6MTc1Mzc3Mzk2NiwicGF0aCI6Ii8zMjY0MDU2Ny80NzE4NjA5NzktZDZjN2JmNDAtMWZiZi00YmY2LTlkMjQtYjk1YTgwY2YzZjllLnBuZz9YLUFtei1BbGdvcml0aG09QVdTNC1ITUFDLVNIQTI1NiZYLUFtei1DcmVkZW50aWFsPUFLSUFWQ09EWUxTQTUzUFFLNFpBJTJGMjAyNTA3MjklMkZ1cy1lYXN0LTElMkZzMyUyRmF3czRfcmVxdWVzdCZYLUFtei1EYXRlPTIwMjUwNzI5VDA3MjYwNlomWC1BbXotRXhwaXJlcz0zMDAmWC1BbXotU2lnbmF0dXJlPTljOGE5NWIzMDNhYjMzMDllMWRiYTBmYjM1NDViNmMyNjA3ZjE1NjEwOWE0NjM3MmFkYTk1MTM0YjA2M2YxY2ImWC1BbXotU2lnbmVkSGVhZGVycz1ob3N0In0.06_lOCtiRdITAXZdtC-vGiZyDHd0ICF9puX5B1gUZGc" width="100%" alt="Ray team acknowledging the potential of Code Server">
</div>

Inspired by this, I decided to explore this approach. [Code Server](https://github.com/coder/code-server) is a VSCode service that runs in a browser, providing an experience almost identical to the desktop VSCode:

<div align="center">
<img src="https://private-user-images.githubusercontent.com/32640567/471868017-29935b15-eb60-496f-8ab8-efd778e73f2e.png?jwt=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3NTM3NzQ1NzIsIm5iZiI6MTc1Mzc3NDI3MiwicGF0aCI6Ii8zMjY0MDU2Ny80NzE4NjgwMTctMjk5MzViMTUtZWI2MC00OTZmLThhYjgtZWZkNzc4ZTczZjJlLnBuZz9YLUFtei1BbGdvcml0aG09QVdTNC1ITUFDLVNIQTI1NiZYLUFtei1DcmVkZW50aWFsPUFLSUFWQ09EWUxTQTUzUFFLNFpBJTJGMjAyNTA3MjklMkZ1cy1lYXN0LTElMkZzMyUyRmF3czRfcmVxdWVzdCZYLUFtei1EYXRlPTIwMjUwNzI5VDA3MzExMlomWC1BbXotRXhwaXJlcz0zMDAmWC1BbXotU2lnbmF0dXJlPTQxZDliYjRiYTdiN2E5NWY4MjZjNmU5NzkzZTFjMDNiNWY4OTQ2OGQyMTk3ZTU4ZDFhOWRlODdjZjJhNGM2NjkmWC1BbXotU2lnbmVkSGVhZGVycz1ob3N0In0.Etej9wL5auJK2kngIjvvX61NdzvWTv-O69tAZiSfK0s" width="100%" alt="Code Server in browser">
</div>

This feature provided a solution to the problem: if VSCode is deployed inside the Kubernetes cluster and accessed via a browser, it can bypass network isolation issues, allowing VSCode to directly access the Ray cluster's internal network. This approach does not require managing SSH keys or configuring complex VSCode Remote connections, making the process straightforward.

To optimize the experience and resolve potential conflicts between different RayJobs, I designed a solution to deploy Code Server as a Sidecar container for the Ray Head. This not only ensures that Code Server shares the lifecycle with the Ray cluster but also allows direct access to Ray's working directory, achieving seamless integration.

Based on this approach, I developed a specialized image and uploaded it to Dockerhub: [onesizefitsquorum/code-server-with-ray-distributed-debugger](https://hub.docker.com/r/onesizefitsquorum/code-server-with-ray-distributed-debugger). This image is based on linuxserver/code-server:4.101.2 and comes pre-installed with Python, Ray, debugpy, and other necessary dependencies, as well as VSCode's Python Run/Debug and Ray Distributed Debugger plugins.

Here is the core [Dockerfile](https://github.com/OneSizeFitsQuorum/Code-Server-With-Ray-Distributed-Debugger/blob/main/Dockerfile) for the image:

```dockerfile
FROM linuxserver/code-server:4.101.2

RUN sudo apt-get update && apt-get install -y software-properties-common && sudo add-apt-repository ppa:deadsnakes/ppa && apt-get install -y python3 python3-pip && pip3 install ray[default] debugpy --break-system-packages

RUN mkdir -p /config/extensions \
    && curl -L -o /config/extensions/ms-python.python.vsix https://marketplace.visualstudio.com/_apis/public/gallery/publishers/ms-python/vsextensions/python/2025.10.0/vspackage \
    && curl -L -o /config/extensions/ms-python.debugpy.vsix https://marketplace.visualstudio.com/_apis/public/gallery/publishers/ms-python/vsextensions/debugpy/2025.10.0/vspackage \
    && curl -L -o /config/extensions/anyscalecompute.ray-distributed-debugger.vsix https://marketplace.visualstudio.com/_apis/public/gallery/publishers/anyscalecompute/vsextensions/ray-distributed-debugger/0.1.4/vspackage \
    && /app/code-server/bin/code-server --extensions-dir /config/extensions --install-extension ms-python.python \
    && /app/code-server/bin/code-server --extensions-dir /config/extensions --install-extension ms-python.debugpy \
    && /app/code-server/bin/code-server --extensions-dir /config/extensions --install-extension anyscalecompute.ray-distributed-debugger
```

Next, configure Code Server as a Sidecar container for the Pod hosting the Ray Head, ensuring it shares the working directory with Ray. Note that Code Server needs to use the custom image uploaded to DockerHub earlier. Key Kubernetes configuration snippets are as follows:

```yaml
containers:
- image: rayproject/ray:2.46.0
  name: ray-head
  ports:
  - containerPort: 6379
    name: gcs-server
  - containerPort: 8265
    name: dashboard
  - containerPort: 10001
    name: client
  resources:
    limits:
      cpu: "500m"
    requests:
      cpu: "200m"
  volumeMounts:
    - mountPath: /tmp/ray
      name: shared-ray-volume
- name: vscode-debugger
  image: docker.io/onesizefitsquorum/code-server-with-ray-distributed-debugger:4.101.2
  imagePullPolicy: IfNotPresent
  ports:
    - containerPort: 8443
  volumeMounts:
    - mountPath: /tmp/ray
      name: shared-ray-volume
  env:
    - name: PUID
      value: "1000"
    - name: PGID
      value: "1000"
    - name: TZ
      value: "Asia/Shanghai"
    - name: DEFAULT_WORKSPACE
      value: "/tmp/ray/session_latest/runtime_resources"
    - name: SUDO_PASSWORD
      value: "root"
volumes:
- name: shared-ray-volume  # Shared volume for /tmp/ray
  emptyDir: {} 
```

# Deployment Example

Through the technical exploration above, we've successfully made Ray Distributed Debugger usable in the Kuberay environment. Below is a complete example of using Ray Distributed Debugger in a Kuberay cluster with the work from this article. All related code and configuration files have been uploaded to the [GitHub repository](https://github.com/OneSizeFitsQuorum/Code-Server-With-Ray-Distributed-Debugger/tree/main/example) for reference and use.

For developers with specific business requirements, you only need to understand the core logic of the example code to easily extend and implement custom Debugger management functions without redeveloping basic components and images.

## Development Environment Options

When performing development and debugging, you can choose between local environments or cloud development environments. For cloud development, GitHub Codespaces provides a convenient option:

- Each GitHub account has 60 hours of free usage per month
- The free tier provides a Linux environment with 2 CPU cores, 4GB RAM, and 32GB storage
- It comes pre-installed with Docker, Kubernetes toolchain, and other essential development tools
- You can develop directly in your browser without local environment configuration

These resources are sufficient for running the example code in this article and small Kubernetes clusters (like kind, k3d, etc.), making it ideal for learning and testing Ray's debugging capabilities.

## Deployment Steps

The specific steps are as follows:

1. Ensure that Kubernetes, Kuberay Operator, and the Kubectl ray plugin are installed. If using GitHub Codespaces, you can install these tools directly in the terminal.

2. Enter the example directory and execute the following command to start a cluster containing Ray Head, Code Server, and Ray Worker:

```shell
kubectl ray job submit -f ray-job.interactive-mode.yaml --working-dir ./working_dir --runtime-env-json="{\"pip\": [\"debugpy\"], \"py_modules\": [\"./dependency\"]}" -- python sample_code.py
```

3. After the cluster starts, it will automatically install debugpy and transfer the working directory and module files to the Ray Cluster. When the code execution reaches the `breakpoint()` statement, it will wait for the debugger to attach.

4. Use the following command to forward the Code Server port:

```shell
kubectl port-forward pod/the-name-of-ray-head 8443:8443
```

5. Open a browser and visit `http://127.0.0.1:8443` to enter the Code Server interface. If running in GitHub Codespaces, you can leverage its port forwarding functionality, which automatically creates accessible URLs.

6. In Code Server, use the Ray Distributed Debugger plugin to connect to `127.0.0.1:8265` (the Ray Head's Dashboard address) to see and connect to all breakpoints.

The interface after successful deployment looks like this:

<div align="center">
<img src="https://private-user-images.githubusercontent.com/32640567/471882960-73272198-3e72-4d5c-add4-4f61ad6b9ec1.png?jwt=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3NTM3NzY4MzYsIm5iZiI6MTc1Mzc3NjUzNiwicGF0aCI6Ii8zMjY0MDU2Ny80NzE4ODI5NjAtNzMyNzIxOTgtM2U3Mi00ZDVjLWFkZDQtNGY2MWFkNmI5ZWMxLnBuZz9YLUFtei1BbGdvcml0aG09QVdTNC1ITUFDLVNIQTI1NiZYLUFtei1DcmVkZW50aWFsPUFLSUFWQ09EWUxTQTUzUFFLNFpBJTJGMjAyNTA3MjklMkZ1cy1lYXN0LTElMkZzMyUyRmF3czRfcmVxdWVzdCZYLUFtei1EYXRlPTIwMjUwNzI5VDA4MDg1NlomWC1BbXotRXhwaXJlcz0zMDAmWC1BbXotU2lnbmF0dXJlPWY5NDcyZDI3ZTIzM2Q2ZWNmZWUwYmJhMzI1ZDRlNmQ0MjgwNzQyYzEzNTJmOGRmOGZiZjJmZjYyN2MyNjExOWQmWC1BbXotU2lnbmVkSGVhZGVycz1ob3N0In0.TGQZSKrJ15UtuYztMMnOn53maNH2SKNb246mf8_4Nhw" width="100%" alt="Code Server with Ray Distributed Debugger in action">
</div>

<div align="center">
<img src="https://private-user-images.githubusercontent.com/32640567/471883076-f3be4acc-82e5-4ad0-84ee-53ff1fe9be08.png?jwt=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3NTM3NzY4NTQsIm5iZiI6MTc1Mzc3NjU1NCwicGF0aCI6Ii8zMjY0MDU2Ny80NzE4ODMwNzYtZjNiZTRhY2MtODJlNS00YWQwLTg0ZWUtNTNmZjFmZTliZTA4LnBuZz9YLUFtei1BbGdvcml0aG09QVdTNC1ITUFDLVNIQTI1NiZYLUFtei1DcmVkZW50aWFsPUFLSUFWQ09EWUxTQTUzUFFLNFpBJTJGMjAyNTA3MjklMkZ1cy1lYXN0LTElMkZzMyUyRmF3czRfcmVxdWVzdCZYLUFtei1EYXRlPTIwMjUwNzI5VDA4MDkxNFomWC1BbXotRXhwaXJlcz0zMDAmWC1BbXotU2lnbmF0dXJlPTk2OTNiZjk4OGQ5MGU1YmQ5NDkwOTdiNTI3MjZkMjBmYjQ0MDZmZWIyY2VlNDJkZjg0MDA3YWYwNjI5Mjk3MWYmWC1BbXotU2lnbmVkSGVhZGVycz1ob3N0In0.UydGOioZ2LiiBngITqp8deZ6RfvbsPPT6eW7Nl6udd8" width="100%" alt="Debugging a Ray worker in Code Server">
</div>

# Conclusion and Reflections

Through this exploration, we found a method to use Ray Distributed Debugger in the Kuberay environment. This solution uses Code Server as an intermediate layer to solve connection problems caused by Kubernetes network isolation. The main takeaways are as follows:

1. **Solved a Practical Problem**: Successfully resolved the connection barrier caused by Kubernetes network isolation mechanism for Ray Distributed Debugger by using Code Server as a bridge.

2. **Provided a Practical Solution**: The solution includes complete image building, configuration templates, and usage guides that can be directly applied to actual development environments.

3. **Simplified Operation Process**: Adopted the Sidecar container mode to ensure shared lifecycle with the Ray cluster, and achieved seamless resource access through shared volumes.

4. **Inspired Thinking**: This solution is not only applicable to Ray Distributed Debugger but may also be suitable for other development and debugging scenarios in Kubernetes environments.

From a broader perspective, this attempt also triggered some reflections:

* **Development Experience in Cloud-Native Environments**: As cloud-native technologies become more widespread, how to provide a good development experience while maintaining isolation is a worthy issue to consider. Both the Code Server mentioned in this article and cloud development environments like GitHub Codespaces are evolving toward simplifying the developer experience.

* **Prospects for Browser-Based IDEs**: Browser-based VSCode allows developers to obtain a consistent development experience on different devices, and this mode has great potential in cloud development environments. Both Code Server and Codespaces adopt this model, lowering the barrier to environment configuration.

* **Value of Open Source Community Collaboration**: The solution to this problem originated from community discussions and will be fed back to the community, embodying the value of open source collaboration.

I plan to share this solution with the Ray community, hoping to help developers with similar needs. At the same time, community members are welcome to improve and refine the solution.