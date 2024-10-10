import { hilog } from '@kit.PerformanceAnalysisKit';
import socket from '@ohos.net.socket';
import wifiManager from '@ohos.wifiManager';
import { netQuality } from '@kit.NetworkBoostKit';
import { netHandover } from '@kit.NetworkBoostKit';
import { connection } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { JSON } from '@kit.ArkTS';
import { HashMap } from '@kit.ArkTS';
import { systemDateTime } from '@kit.BasicServicesKit';


class SocketInfo {
  message: ArrayBuffer = new ArrayBuffer(1);
  remoteInfo: socket.SocketRemoteInfo = {} as socket.SocketRemoteInfo;
}

// 定义心跳包的数据类型
interface HeartbeatData {
  type: string;
  timestamp: string;
  receive: string;
}

// 创建一个TCPSocketServer连接，返回一个TCPSocketServer对象。
let tcp: socket.TCPSocket = socket.constructTCPSocketInstance();
// 绑定目标IP地址和端口，进行监听
let ipAddress: socket.NetAddress = {} as socket.NetAddress;
ipAddress.address = "113.45.216.93";
ipAddress.port = 9090;

@Entry
@Component
struct Index {
  @State message_send: string = 'Hello World';
  @State message_recv: string = '';
  @State status: string = '未连接';
  @State received_count: number = 0;
  @State sequence_number: number = 0; // Initialize sequence_number
  @State heartbeat_count: number = 0;
  @State linkBreak: number = 0
  @State delay: number = 0
  @State showToken: string = '';
  @State content: string = '';
  @State receive: number = 0 //已接受的序号
  // @State rate: number = this.receive / 200.0
  private delays: HashMap<number, number> = new HashMap();
  previousPort: number = 0;
  heartbeatInterval: number = 30000; // 初始心跳间隔为30秒
  maxHeartbeatInterval: number = 60000; // 最大心跳间隔为60秒
  minHeartbeatInterval: number = 10000; // 最小心跳间隔为10秒
  networkType: string = '';
  localAddr: socket.NetAddress = {
    address: this.resolveIP(wifiManager.getIpInfo().ipAddress),
    port: 9999,
    family: 1
  };
  adjustHeartbeatInterval(success: boolean) {
  if (success) {
    this.heartbeatInterval = Math.min(this.heartbeatInterval + 5000, this.maxHeartbeatInterval);
  } else {
    this.heartbeatInterval = Math.max(this.heartbeatInterval - 5000, this.minHeartbeatInterval);
  }
}

  startHeartbeat() {
    setInterval(() => {
      tcp.getState().then((data: socket.SocketStateBase) => {
        if (!data.isConnected) {
          this.status = '断开连接，重新连接中';
          this.linkBreak += 1;
          this.tcpConnect();
        } else {
          this.sendHeartbeat();
        }
      }).catch((err: BusinessError) => {
        this.status = '检查连接状态失败';
      });
    }, this.heartbeatInterval);
  }

  sendHeartbeat() {
    this.tcpSend().then(() => {
      this.heartbeat_count += 1;
      this.adjustHeartbeatInterval(true);
    }).catch((err: BusinessError) => {
      this.adjustHeartbeatInterval(false);
      this.status = '心跳发送失败，调整心跳间隔';
    });
  }

  tcpSend() {
    // 构建心跳包 JSON 数据
    const heartbeatData: HeartbeatData = {
      type: 'heartbeat',
      timestamp: new Date().toISOString(),
      receive: String(this.receive)
    };

    // 将 JSON 数据转换为字符串并编码为 Uint8Array
    let tcpSendOptions: socket.TCPSendOptions = {
      data: JSON.stringify(heartbeatData)
    };

    return tcp.send(tcpSendOptions).then(() => {
      console.log('Heartbeat sent successfully');
    }).catch((err: BusinessError) => {
      console.log('Heartbeat send failed', err);
      throw new Error('Heartbeat send failed'); // Use a standard error message for throwing
    });
  }


  tcpConnect() {
    tcp.on('message', (value: socket.SocketMessageInfo) => {
      this.message_recv = this.resolveArrayBuffer(value.message)
      this.receive += 1
      let obj = JSON.parse(this.message_recv);
      this.delay = systemDateTime.getUptime(systemDateTime.TimeType.ACTIVE, false) - (obj as object)?.['time'];
      if (this.delays.hasKey(this.delay)) {
        this.delays.set(this.delay, this.delays.get(this.delay) + 1)
      } else {
        this.delays.set(this.delay, 1);
      }
    });
    tcp.on('close', () => {
      this.status = '已断开';
      this.linkBreak += 1
      console.info("on close success");
    });

    //连接设置
    let tcpConnect: socket.TCPConnectOptions = {} as socket.TCPConnectOptions;
    tcpConnect.address = ipAddress;
    tcpConnect.timeout = 6000;
    // 连接到目标地址
    tcp.connect(tcpConnect).then(() => {
      this.status = '已连接';
      this.sendHeartbeat();
    }).catch((err: BusinessError) => {
      this.status = '连接失败';
    });
  }

  tcpClose() {
    tcp.close().then(() => {
      console.log('close success');
      this.status = "已断开"
    }).catch((err: BusinessError) => {
      console.log('close fail');
    });
    tcp.off('message');
    tcp.off('connect');
    tcp.off('close');
  }

  resolveArrayBuffer(message: ArrayBuffer): string {
    if (message instanceof ArrayBuffer) {
      let dataView = new DataView(message);
      let str = "";
      for (let i = 0; i < dataView.byteLength; ++i) {
        let c = String.fromCharCode(dataView.getUint8(i));
        if (c !== "\n") {
          str += c;
        }
      }
      return str;
    }
    return "";
  }

  resolveIP(ip: number): string {
    if (ip < 0 || ip > 0xFFFFFFFF) {
      throw new Error("The number is not normal!");
    }
    return (ip >>> 24) + "." + (ip >> 16 & 0xFF) + "." + (ip >> 8 & 0xFF) + "." + (ip & 0xFF);
  }

  build() {
    RelativeContainer() {
      Column() {
        Text('Socket Test')
          .id('Socket')
          .fontSize(40)
          .fontWeight(FontWeight.Bold)
          .alignRules({
            middle: { anchor: '__container__', align: HorizontalAlign.Center }
          });
        Text('localAddr:[' + this.localAddr.address + '],\ntargetAddr:[' + ipAddress.address + ']\n')
          .fontSize(25)
          .width('100%')
          .margin({ top: 10 })
          .alignRules({
            top: { anchor: 'Socket', align: VerticalAlign.Bottom }
          })
          .textAlign(TextAlign.Center);

        Text('已接受序号:[' + String(this.receive) + ']\n')
          .fontSize(25)
          .width('100%')
          .margin({ top: 5 })
          .alignRules({
            top: { anchor: 'Socket', align: VerticalAlign.Bottom }
          })
          .textAlign(TextAlign.Center);
        Text(`状态: ${this.status}, 断链次数: ${this.linkBreak}`)
          .fontSize(25)
          .width('100%')
          .margin({ top: 5 })
          .textAlign(TextAlign.Center);
        Text(`已接收信息: ${String(this.receive)}`)
          .fontSize(25)
          .width('100%')
          .margin({ top: 5 })
          .textAlign(TextAlign.Center);

        Text(`目前接收消息比率: ${( 1 > 0 ? (this.receive/200.0).toFixed(2) :'0')}%`)
          .fontSize(25)
          .width('100%')
          .margin({ top: 5 })
          .textAlign(TextAlign.Center);

        Button('连接TCP')
          .width('90%')
          .height(80)
          .margin({ top: 20 })
          .type(ButtonType.Capsule)
          .onClick(() => {
            this.tcpConnect();
          });

        Button('接受TCP消息')
          .width('90%')
          .height(80)
          .margin({ top: 20 })
          .type(ButtonType.Capsule)
          .onClick(() => {

          });

        Button('关闭TCP连接')
          .width('90%')
          .height(80)
          .margin({ top: 20 })
          .type(ButtonType.Capsule)
          .onClick(() => {
            this.tcpClose();
          });
      }
    }
    .height('100%')
    .width('100%');
  }
}