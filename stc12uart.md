
## UART1
| mode        | fuction                            |
|-------------|------------------------------------|
| SM0=0 SM1=0 | 同步移位寄存器                     |
| SM0=0 SM1=1 | 8位UART，波特率可变 |
| SM0=1 SM1=0 | 9位UART，波特率固定                |
| SM0=1 SM1=1 | 9位UART，波特率可变                |


### 多机通信机制  只有方式2和3可以用
| SM2 | TB8 | 接收 |
|-----|-----|------|
| 0   | 0   | Y    |
| 0   | 1   | Y    |
| 1   | 0   | N    |
| 1   | 1   | Y    |

