//wifi模块，用于获取当前IP地址
import wifi from '@ohos.wifi';
import socket from '@ohos.net.socket';
//tcp连接对象
let tcp = socket.constructTCPSocketInstance();

//目标地址和端口
let targetAddr:socket.NetAddress = {
  address: '114.116.227.106',  //要通信的 PC地址
  family: 1,
  port: 9999 //UDP:7001/TCP:8001
}


@Entry
@Component
struct Index {
  @State message_send: string= 'hello'
  @State message_recv: string= ''
  @State status: string= '未连接'

  //本地地址和端口
  localAddr:socket.NetAddress = {
    address: this.resolveIP(wifi.getIpInfo().ipAddress)
  }
  tcpInit() {

    //bind本地地址
    tcp.bind({ address: this.localAddr.address, port: 8000, family: 1 })
      .then(() => {

      }).catch();
  }

  tcpConnect() {
    tcp.getState()
      .then((data) => {
        if (data.isClose) {
          this.tcpInit()
        }else {
          tcp.on('connect', () => {
            this.status = '已连接'
          });
          tcp.on('message', value => {
            this.message_recv = this.resolveArrayBuffer(value.message)
          });
          tcp.on('close', () => {
            this.status='已断开'
          });
        }
        //开始连接
        tcp.connect(
          {
            address: { address: targetAddr.address, port: 9999, family: 1 }, timeout: 6000
          }
        ).then(() => {


        }).catch(() => {
        })

      })
  }

  tcpSend() {
    //查看状态
    tcp.getState().then((data) => {
      //已连接,就发送数据
      if (data.isConnected) {
        //发送消息
        tcp.send(
          { data: this.message_send, }
        ).then(() => {

        }).catch(() => {

        })
      } else {

      }
    })
  }

  tcpClose() {
    tcp.close().then(() => {
      this.status = '已断开'

    })
    tcp.off('close');
    tcp.off('message');
    tcp.off('connect');
  }

  //解析ArrayBuffer
  resolveArrayBuffer(message: ArrayBuffer): string {
    if (message instanceof ArrayBuffer) {
      let dataView = new DataView(message)

      let str = ""
      for (let i = 0;i < dataView.byteLength; ++i) {
        let c = String.fromCharCode(dataView.getUint8(i))
        if (c !== "\n") {
          str += c
        }
      }

      return str;
    }
    return "";
  }

  //解析本地IP,需要声明ohos.permission.GET_WIFI_INFO权限
  resolveIP(ip:number) {
    if (ip < 0 || ip > 0xFFFFFFFF) {
      throw new Error("The number is not normal!");
    }
    return (ip >>> 24) + "." + (ip >> 16 & 0xFF) + "." + (ip >> 8 & 0xFF) + "." + (ip & 0xFF);
  }

  build() {
    Column() {
      Text(`Socket Test`)
        .fontSize(40)
        .width('100%')
        .margin({ top: 50 })
        .textAlign(TextAlign.Center)

      Text(`localAddr:[${this.localAddr.address}],targetAddr:[${targetAddr.address}](${this.status})`)
        .fontSize(25)
        .width('100%')
        .margin({ top: 10 })
        .textAlign(TextAlign.Center)

      TextInput({ placeholder: '请输入信息', text: this.message_send })
        .height(60).width('90%').margin({ top: 20 })
        .onChange((value: string) => {
          this.message_send = value
        })

      TextInput({ placeholder: '已接收信息', text: this.message_recv })
        .height(60).width('90%').margin({ top: 20 })


      Button('连接TCP')
        .width('90%')
        .height(80)
        .margin({ top: 20 })
        .type(ButtonType.Capsule)
        .onClick(() => {
          this.tcpConnect()
        })

      Button('发送TCP消息')
        .width('90%')
        .height(80)
        .margin({ top: 20 })
        .type(ButtonType.Capsule)
        .onClick(() => {
          this.tcpSend()
        })

      Button('关闭TCP连接')
        .width('90%')
        .height(80)
        .margin({ top: 20 })
        .type(ButtonType.Capsule)
        .onClick(() => {
          this.tcpClose()
        })

    }
    .height('100%')
    .width('100%')
    //.backgroundColor(Color.Black)
  }
}