# huawei_tcp_long_connection

---

# 1. 简介
## 1.1 背景
本文档旨在描述基于OpenHarmony的TCP连接应用程序的设计与实现。项目背景是为了构建一个可以自动处理网络连接状态的客户端，包括心跳机制、断线重连、消息接收和发送等功能。此文档记录了系统的整体设计思路及各模块的功能和实现细节。

## 1.2 目的
该文档的目的是描述如何实现一个基于Socket API的TCP客户端，以便于在网络环境中进行稳定的数据传输。文档内容将指导开发人员理解系统架构、模块分解和接口调用方式，为编码提供设计参考。

# 2. 设计描述
## 2.1 总体设计
该系统设计了一个基于Socket的TCP客户端，包括连接、消息发送、消息接收、心跳机制和自动重连等功能。系统需要稳定处理网络连接，并能够应对掉线重连情况，同时优化心跳间隔以保证连接的稳定性。

## 2.2 实现思路
通过使用OpenHarmony的Socket API进行TCP连接，客户端可以与指定的服务器建立连接并进行双向通信。系统通过自动调整心跳包的发送频率来维持连接状态，并在检测到连接断开时自动重连。为了应对端口占用情况，采用随机端口策略来减少冲突。

## 2.3 系统结构
### 2.3.1 模块划分
系统划分为以下主要模块：
- **网络管理模块**：负责IP地址的解析、随机端口生成及网络状态的管理。
- **TCP连接模块**：负责TCP的连接、绑定、消息发送与接收。
- **心跳管理模块**：实现自动调整心跳间隔，并定期发送心跳包。
- **UI模块**：负责用户界面的显示与交互，包括连接状态、消息展示等。

### 2.3.2 系统架构说明
通过MVC模式对系统进行设计：
- **Model**：包括网络状态、心跳计数、断链计数等数据存储和管理。
- **View**：通过界面展示连接状态、接收的信息、发送的心跳包数。
- **Controller**：处理用户的操作，如连接、断开、消息发送等，并控制Model和View的交互。

### 2.3.3 文件结构
- `src/components/Index.ark`: 主界面及业务逻辑
- `src/services/socketService.ts`: TCP连接管理服务
- `src/utils/portHelper.ts`: 随机端口生成及IP解析工具
- `src/styles`: 界面样式文件

## 2.4 模块功能描述
### 2.4.1 网络管理模块
- **标识**：`NetworkManager`
- **类型**：模块
- **目的**：负责管理本地IP解析及端口选择。
- **功能列表**：
  - `resolveIP`：解析本地IP地址。
  - `getRandomPort`：生成随机端口号，避免常见端口冲突。
- **处理**：通过获取WiFi信息中的IP，并将其转换为字符串格式，同时过滤已占用的端口。

### 2.4.2 TCP连接模块
- **标识**：`TCPClient`
- **类型**：模块
- **目的**：负责与服务器建立TCP连接，并处理消息的发送与接收。
- **功能列表**：
  - `tcpConnect`：与服务器建立TCP连接。
  - `tcpSend`：向服务器发送数据。
  - `tcpClose`：关闭TCP连接并释放资源。
  - `startReceivingMessages`：监听并处理从服务器接收到的消息。
- **处理**：在连接前关闭现有连接，释放端口后重新绑定并连接到目标服务器。

### 2.4.3 心跳管理模块
- **标识**：`HeartbeatManager`
- **类型**：模块
- **目的**：通过定期发送心跳包维持TCP连接的稳定性。
- **功能列表**：
  - `startHeartbeat`：定时检查连接状态并发送心跳包。
  - `adjustHeartbeatInterval`：根据发送成功与否调整心跳间隔。
- **处理**：通过定时器定期检查TCP连接状态，如果断开则自动重新连接。

## 2.5 业务/实现流程说明
### 2.5.1 用例1处理流程：TCP连接
- 用户点击“连接TCP”按钮，触发`tcpConnect`方法。
- 系统生成随机端口，并绑定到本地地址。
- 调用Socket API连接到指定IP地址和端口。
- 连接成功后，系统启动心跳机制。

### 2.5.2 用例2处理流程：接收消息
- 用户点击“接受TCP消息”按钮。
- 系统检查当前TCP连接状态，若已连接，则调用`startReceivingMessages`。
- 收到消息时，解析消息内容并显示在UI界面上。

## 2.6 接口描述
### 2.6.1 调用接口
- `wifiManager.getIpInfo()`: 获取WiFi信息中的IP地址。
- `socket.constructTCPSocketInstance()`: 创建TCP实例。
- `tcp.getState()`: 获取当前TCP连接状态。

### 2.6.2 提供接口
- `resolveIP()`: 将IP地址转换为字符串格式。
- `getRandomPort()`: 返回未占用的随机端口。
- `adjustHeartbeatInterval()`: 调整心跳间隔时间。

## 2.7 UI设计
UI设计采用简洁的布局，主要展示当前连接状态、接收信息以及发送心跳的计数。界面通过按钮提供交互功能，用户可以手动连接、发送消息和关闭连接。

# 3. 其他
## 3.1 成员分工
  无分工

## 3.2 困难与思考
- 如何优化心跳机制以平衡频率与电量消耗。
- 解决断开连接后端口占用的问题，确保能够顺利重连。

## 3.3 参考
- OpenHarmony官方文档
- IETF相关协议规范
- 网络编程最佳实践

---

```
client
├── AppScope
├── entry
│   └── src
│       ├── main
│       │   ├── ets
│       │   │   ├── entryability
│       │   │   │   └── EntryAbility.ets
│       │   │   ├── entrybackupability
│       │   │   │   └── EntryBackupAbility.ets
│       │   │   └── pages
│       │   │       └── Index.ets
│       │   ├── module.json5
│       │   └── resources
│       │       ├── base
│       │       │   ├── element
│       │       │   │   ├── color.json
│       │       │   │   └── string.json
│       │       │   ├── media
│       │       │   │   ├── background.png
│       │       │   │   ├── foreground.png
│       │       │   │   ├── layered_image.json
│       │       │   │   └── startIcon.png
│       │       │   └── profile
│       │       │       ├── backup_config.json
│       │       │       └── main_pages.json
│       │       ├── en_US
│       │       │   └── element
│       │       │       └── string.json
│       │       ├── rawfile
│       │       └── zh_CN
│       │           └── element
│       │               └── string.json

```


希望这份文档结构能帮助你更好地描述和组织项目内容！如果有其他调整需要，可以继续完善。


#### 约束与限制
本示例仅支持标准系统上运行，支持设备：dayu200。

本示例支持API12版本SDK，镜像版本号: OpenHarmony 5.0。

本示例需要使用DevEco Studio NEXT Beta1编译运行

本示例在启动前需搭建服务端环境，成功启动相应服务端后再运行客户端，服务端脚本（./server/server_final.py）需要在Python 3.8版本下运行。

该示例运行测试完成后，再次运行需要重新启动服务端和客户端。



