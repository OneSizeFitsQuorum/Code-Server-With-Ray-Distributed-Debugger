<!-- TOC -->

- [背景](#%E8%83%8C%E6%99%AF)
- [Ray Distributed Debugger 在 Kuberay 环境下的问题](#ray-distributed-debugger-%E5%9C%A8-kuberay-%E7%8E%AF%E5%A2%83%E4%B8%8B%E7%9A%84%E9%97%AE%E9%A2%98)
- [技术探索](#%E6%8A%80%E6%9C%AF%E6%8E%A2%E7%B4%A2)
    - [请求代理方案的探索与局限](#%E8%AF%B7%E6%B1%82%E4%BB%A3%E7%90%86%E6%96%B9%E6%A1%88%E7%9A%84%E6%8E%A2%E7%B4%A2%E4%B8%8E%E5%B1%80%E9%99%90)
    - [Code-Server：浏览器端 VSCode 的解决方案](#code-server%E6%B5%8F%E8%A7%88%E5%99%A8%E7%AB%AF-vscode-%E7%9A%84%E8%A7%A3%E5%86%B3%E6%96%B9%E6%A1%88)
- [部署示例](#%E9%83%A8%E7%BD%B2%E7%A4%BA%E4%BE%8B)
    - [开发环境选择](#%E5%BC%80%E5%8F%91%E7%8E%AF%E5%A2%83%E9%80%89%E6%8B%A9)
    - [部署步骤](#%E9%83%A8%E7%BD%B2%E6%AD%A5%E9%AA%A4)
- [总结与思考](#%E6%80%BB%E7%BB%93%E4%B8%8E%E6%80%9D%E8%80%83)

<!-- /TOC -->

# 背景

在软件开发过程中，具备单步调试能力的 Debugger 是提升开发效率的关键工具。对于复杂的分布式系统而言，单步调试能力尤为重要，它能帮助开发者在纷繁复杂的同步/异步代码链路中快速定位问题，从而缩短问题诊断周期。

以分布式存储系统为例，2021 年我曾通过 IDEA 配置 Apache IoTDB 3C3D 集群的单步调试能力（可参考[博客](https://tanxinyu.work/cluster-iotdb-idea-debugger/)）。在随后的几年里，这套方案帮助我解决了 IoTDB 分布式开发过程中的不少疑难问题，提升了开发效率。

最近，我开始学习并研究分布式计算框架 Ray，首先从其调试功能入手。Ray 官方目前支持两种 Debugger，具体使用方式可参考官方文档，这里简要介绍：
* [Ray Debugger](https://docs.ray.io/en/latest/ray-observability/user-guides/debug-apps/ray-debugging.html)：通过 Ray debug 命令复用 pdb session 命令行进行单步调试。从 2.39 版本开始已被标记为废弃，不推荐使用。
* [Ray Distributed Debugger](https://docs.ray.io/en/latest/ray-observability/ray-distributed-debugger.html)：通过 VSCode 插件复用 pydebug 图形界面进行单步调试，体验更佳。目前是 Ray 官方社区推荐的默认调试工具。

> 注意：Ray Cluster 启动时需配置相应的 Debugger 参数，且上述两种 Debugger 不支持同时使用。

Ray Distributed Debugger 的核心原理是基于 Ray 内核中默认开启的 RAY_DEBUG 环境变量。当触发断点时，所有 Worker 会周期性地将断点信息汇总到 Head 节点。VSCode 插件通过连接 Ray Head 节点获取断点列表，用户可进一步点击 Start Debugging，attach 到对应 Worker 上进行单步调试。其官方文档大纲如下：

<div align="center">
<img src="https://picx.zhimg.com/v2-845b602c6a1d3045d334f8b874aa6aed_1440w.jpg" width="100%" alt="Ray Distributed Debugger Architecture">
</div>

# Ray Distributed Debugger 在 Kuberay 环境下的问题

如上所述，Ray Distributed Debugger 需要能够网络连接到触发断点的 Worker，才能实现单步调试。在裸机部署场景下，只需配置好防火墙规则即可满足需求。然而，随着云原生技术的普及，目前大多数分布式计算框架都基于 Kubernetes（K8S）进行资源管理。此时，用户通常会选择安装 [Kuberay](https://github.com/ray-project/kuberay)，并通过 RayCluster/RayJob/RayServe 等自定义资源进行 Ray 集群的生命周期和资源控制。

在 K8S 环境下，由于其网络隔离机制，Ray 集群实际运行在集群内部的隔离网络空间中，外部默认无法直接访问 Ray Cluster 的各个组件。Ray Distributed Debugger 需要连接 Ray Head 节点的 dashboard 端口（8265）才能获取所有断点信息，此时我们可以将 Ray Head 的 8265 端口暴露出来，使 Ray Distributed Debugger 能够获取到集群中触发的断点列表。

以下是一个在 Kuberay 环境下测试 Ray Distributed Debugger 的例子：

1. 首先安装好 K8S 集群和 kuberay-operator，然后使用 RayJob 模式提交一个会触发断点的任务。

<div align="center">
<img src="https://pic1.zhimg.com/v2-0daa2ab49c63986d08385d82b6384a2c_1440w.jpg" width="100%" alt="Submit RayJob with breakpoint">
</div>

2. 当代码中触发断点时，会在 job submitter 侧打印日志，表明 debugger 正在等待 attach：

<div align="center">
<img src="https://pic4.zhimg.com/v2-9554551a76582f37a400504091a5bdc7_1440w.jpg" width="100%" alt="Debugger waiting for attach">
</div>

3. 我们使用 `kubectl port-forward` 命令将 Head 节点的 8265 端口转发到本地的 8265 端口，并通过 Ray Distributed Debugger 连接。此时可以看到集群中触发的所有断点：

<div align="center">
<img src="https://pic4.zhimg.com/v2-e5e584b3035c0da60cf6748083725cf5_1440w.jpg" width="100%" alt="Ray Distributed Debugger showing breakpoints">
</div>

4. 然而，当尝试连接任意一个断点进行调试时，系统显示无法 attach 到断点，报错如下：

<div align="center">
<img src="https://pic3.zhimg.com/v2-02dd228bf9ab5c2a3a40ccafd6a92d5c_1440w.jpg" width="100%" alt="Connection error to breakpoint">
</div>


5. 分析错误信息后发现，问题在于 Ray Distributed Debugger 插件尝试连接的是 Kubernetes 集群内部的 IP 和端口。这些 IP 和端口在集群外部无法直接访问，且端口是随机分配的，无法提前进行端口映射，因此导致连接失败。

以上示例表明，在 Kuberay 环境下使用 Ray Distributed Debugger 存在实际困难。

值得一提的是，在官方文档中我们还发现一个 [PR](https://github.com/ray-project/ray/pull/49116)，提出了通过在 Ray Head 镜像中安装 SSH，并利用 VSCode Remote 进行连接的方案。虽然理论上可行，但这种方式操作较为复杂，涉及密钥管理、生命周期管理等问题，因此被用户诟病。

<div align="center">
<img src="https://pic3.zhimg.com/v2-11eeb4f7b620b3802322346de4a79820_1440w.jpg" width="100%" alt="User complaint about SSH approach">
</div>

<div align="center">
<img src="https://pic4.zhimg.com/v2-ee2234aed2a329f1d1ba635b5395d105_1440w.jpg" width="100%" alt="More complaints about SSH approach">
</div>

通过分析，我们发现 Ray 官方目前对于 Ray Distributed Debugger 在 Kuberay 环境下的支持不够完善，需要一个更便捷的解决方案。

# 技术探索

在 Kubernetes 环境下，是否有办法方便地使用 Ray Distributed Debugger？带着这个问题，我进行了一些技术调研和尝试。

## 请求代理方案的探索与局限

首先查阅了 Ray 官方 GitHub 仓库中的相关 issue：[[Ray debugger] Unable to use debugger on Ray Cluster on k8s](https://github.com/ray-project/ray/issues/45541)。从讨论中看出，Ray 官方最初的解决思路是让 Worker 在暴露等待 attach 的端口时使用固定的端口范围，这样用户就可以预先将这些端口暴露到外部进行 attach：

<div align="center">
<img src="https://pica.zhimg.com/v2-095773f02280627cdc714f8541c38a04_1440w.jpg" width="100%" alt="GitHub issue discussion about port ranges">
</div>

有开发者甚至提交了相关 PR 尝试将这一功能集成到 Ray 内核中，但该 PR 最终未被推进，被自动关闭：

<div align="center">
<img src="https://pic2.zhimg.com/v2-3849da11dc29f24280a298341f554a3f_1440w.jpg" width="100%" alt="Closed PR for port range feature">
</div>

推测这种方案未能推进主要是因为存在几个明显的问题：

1. **端口范围设定难题**：如何确定合适的端口范围？范围太小可能无法覆盖所有断点，范围太大可能占用过多集群资源，甚至与 Kubernetes API Server 等系统组件的端口冲突。

2. **操作复杂度高**：即使确定了端口范围，用户仍需手动暴露大量端口，操作繁琐且容易出错，不符合云原生环境下自动化的设计理念。

3. **网络连接障碍**：最关键的问题是，即使端口被成功暴露，Ray Distributed Debugger 的 VSCode 插件仍然会尝试连接 Kubernetes 集群内部的 IP 地址，而这些 IP 在集群外部不可达。由于 VSCode 插件已被 Anyscale 公司闭源管理，我们无法修改其连接逻辑。

理论上，可以通过为每个断点设置 `kubectl port-forward`，然后配合 iptables 规则将本地向 Kubernetes 内部 IP 发送的请求重定向到对应的本地端口，但这种方法操作繁琐、难以自动化，且需要较深的网络知识，在断点数量较多时几乎不可维护。

考虑到这些因素，特别是第三点的根本限制，我放弃了这条技术路径，转而寻找更简单的解决方案。

## Code-Server：浏览器端 VSCode 的解决方案

在前述 issue 的讨论末尾，有用户反馈他们在 Kubernetes 集群中部署 Code Server 后成功解决了该问题：

<div align="center">
<img src="https://picx.zhimg.com/v2-b11c48e7682ed70c8c492c5a7ebd023b_1440w.jpg" width="100%" alt="User suggesting Code Server solution">
</div>

这一思路得到了 Ray 官方的认可，但由于缺乏具体实现细节和完整解决方案，该方案一直停留在概念阶段：

<div align="center">
<img src="https://picx.zhimg.com/v2-c7d2e5fd0bf68c563adecb3aa8b0d415_1440w.jpg" width="100%" alt="Ray team acknowledging the potential of Code Server">
</div>

受此启发，我决定沿着这个思路进行探索。[Code Server](https://github.com/coder/code-server) 是一个在浏览器中运行的 VSCode 服务，提供与桌面版 VSCode 几乎完全一致的开发体验：

<div align="center">
<img src="https://pic3.zhimg.com/v2-ff36fc464e7f12c888fbd23f3ef508a6_1440w.jpg" width="100%" alt="Code Server in browser">
</div>

这一特性为解决问题提供了思路：如果将 VSCode 部署在 Kubernetes 集群内部并通过浏览器访问，就可以规避网络隔离问题，使 VSCode 能够直接访问 Ray 集群内部网络。这种方案不需要管理 SSH 密钥或配置复杂的 VSCode Remote 连接，操作流程简单明了。

为了优化体验并解决不同 RayJob 之间的潜在冲突，我设计了将 Code Server 作为 Ray Head 的 Sidecar 容器部署的方案。这样不仅确保 Code Server 与 Ray 集群共享生命周期，还能直接访问 Ray 的工作目录，实现无缝集成。

基于这一思路，我开发了一个专用镜像并将其放到了 Dockerhub 上：[onesizefitsquorum/code-server-with-ray-distributed-debugger](https://hub.docker.com/r/onesizefitsquorum/code-server-with-ray-distributed-debugger)。该镜像基于 linuxserver/code-server:4.101.2，预装了 Python、Ray、debugpy 等必要依赖，以及 VSCode 的 Python Run/Debug 和 Ray Distributed Debugger 插件。

以下是镜像的核心 [Dockerfile](https://github.com/OneSizeFitsQuorum/Code-Server-With-Ray-Distributed-Debugger/blob/main/Dockerfile)：

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

接下来，配置 Code Server 作为 Ray Head 所在 Pod 的 Sidecar 容器，并确保它与 Ray 共享工作目录。注意 Code Server 需要使用前文上传至 DockerHub 的自定义镜像。关键的 Kubernetes 配置片段如下：

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

# 部署示例

通过以上技术探索，我们成功让 Ray Distributed Debugger 在 Kuberay 环境下可用。下面给出一个结合本文工作在 Kuberay 集群中使用 Ray Distributed Debugger 的完整示例，所有相关代码和配置文件均已上传至 [GitHub 仓库](https://github.com/OneSizeFitsQuorum/Code-Server-With-Ray-Distributed-Debugger/tree/main/example)，方便读者参考和使用。

对于有特定业务需求的开发者，只需理解示例代码的核心逻辑，即可轻松扩展实现自定义的 Debugger 管理功能，无需重复开发基础组件和镜像。

## 开发环境选择

在进行开发调试时，你可以选择本地环境或云端开发环境。对于云端开发，GitHub Codespaces 提供了一个便捷的选项：

- 每个 GitHub 账户每月有 60 小时的免费使用额度
- 免费版配置为 2 核 CPU、4GB 内存和 32GB 存储空间的 Linux 环境
- 预装了 Docker、Kubernetes 工具链等开发必备工具
- 可以直接在浏览器中进行开发，无需本地环境配置

这些资源足以运行本文中的示例代码和小型 Kubernetes 集群（如 kind、k3d 等），非常适合学习和测试 Ray 的调试功能。

## 部署步骤

具体步骤如下：

1. 确保已安装 Kubernetes、Kuberay Operator 和 Kubectl ray 插件。如果使用 GitHub Codespaces，可以直接在终端中安装这些工具。

2. 进入示例目录，执行以下命令启动一个包含 Ray Head、Code Server 和 Ray Worker 的集群：

```shell
kubectl ray job submit -f ray-job.interactive-mode.yaml --working-dir ./working_dir --runtime-env-json="{\"pip\": [\"debugpy\"], \"py_modules\": [\"./dependency\"]}" -- python sample_code.py
```

3. 集群启动后，会自动安装 debugpy 并将工作目录和模块文件传入 Ray Cluster。当代码执行到 `breakpoint()` 语句时，会等待调试器 attach。

4. 使用以下命令转发 Code Server 端口：

```shell
kubectl port-forward pod/the-name-of-ray-head 8443:8443
```

5. 打开浏览器访问 `http://127.0.0.1:8443`，进入 Code Server 界面。如果在 GitHub Codespaces 中运行，可以利用其端口转发功能，系统会自动创建可访问的 URL。

6. 在 Code Server 中，使用 Ray Distributed Debugger 插件连接到 `127.0.0.1:8265`（Ray Head 的 Dashboard 地址），即可看到并连接所有断点。

部署成功后的界面如下：

<div align="center">
<img src="https://pic1.zhimg.com/v2-ca6e6f3225ebb63f742ebfc8edbe3cac_1440w.jpg" width="100%" alt="Code Server with Ray Distributed Debugger in action">
</div>

<div align="center">
<img src="https://pica.zhimg.com/v2-0a421b4ee17a5538174828576aa9c0ca_1440w.jpg" width="100%" alt="Debugging a Ray worker in Code Server">
</div>

# 总结与思考

通过这次探索，我们找到了一种在 Kuberay 环境下使用 Ray Distributed Debugger 的方法。这种方案通过 Code Server 作为中间层，解决了 Kubernetes 网络隔离导致的连接问题。主要有以下几点收获：

1. **解决了实际问题**：通过 Code Server 作为桥梁，成功解决了 Kubernetes 网络隔离机制导致的 Ray Distributed Debugger 连接障碍。

2. **提供了实用方案**：方案包括完整的镜像构建、配置模板和使用指南，可以直接应用于实际开发环境。

3. **简化了操作流程**：采用 Sidecar 容器模式，确保了与 Ray 集群共享生命周期，通过共享卷实现了资源无缝访问。

4. **启发性思考**：这种解决方案不仅适用于 Ray Distributed Debugger，也可能适用于其他在 Kubernetes 环境中进行开发调试的场景。

从更广的角度看，这次尝试也引发了一些思考：

* **云原生环境中的开发体验**：随着云原生技术普及，如何在保持隔离性的同时提供良好的开发体验，是一个值得关注的问题。无论是本文提到的 Code Server，还是 GitHub Codespaces 这样的云端开发环境，都在朝着简化开发者体验的方向发展。

* **浏览器 IDE 的应用前景**：基于浏览器的 VSCode 让开发者能够在不同设备上获得一致的开发体验，这种模式在云开发环境中很有潜力。Code Server 和 Codespaces 都采用了这种模式，降低了环境配置的门槛。

* **开源社区协作的价值**：这个问题的解决思路源于社区讨论，也会回馈给社区，体现了开源协作的价值。

我计划将这个解决方案分享给 Ray 社区，希望能帮助到有类似需求的开发者。同时，也欢迎社区成员对方案进行改进和完善。