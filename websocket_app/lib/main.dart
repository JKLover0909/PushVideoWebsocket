import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'dart:convert';
import 'dart:typed_data';

// Địa chỉ WebSocket server. Truyền khi build/run:
//   flutter run --dart-define=WS_URL=wss://<ngrok-host>/
// Mặc định ws://10.0.2.2:8765 = máy host khi chạy trên Android emulator.
const String kWebSocketUrl = String.fromEnvironment(
  'WS_URL',
  defaultValue: 'ws://10.0.2.2:8765',
);

void main() {
  runApp(const MyApp());
}

// Class để lưu trữ thông tin tin nhắn
class MessageData {
  final String text;
  final Uint8List? imageData;
  final MessageType type;
  final DateTime timestamp;

  MessageData({
    required this.text,
    this.imageData,
    required this.type,
    required this.timestamp,
  });
}

enum MessageType { sent, received, system, image }

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WebSocket Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const WebSocketPage(),
    );
  }
}

class WebSocketPage extends StatefulWidget {
  const WebSocketPage({super.key});

  @override
  State<WebSocketPage> createState() => _WebSocketPageState();
}

class _WebSocketPageState extends State<WebSocketPage> {
  WebSocketChannel? channel;
  final List<MessageData> messages = [];
  bool isConnected = false;
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Sử dụng ValueNotifier để tối ưu performance
  final ValueNotifier<Uint8List?> currentFrameNotifier =
      ValueNotifier<Uint8List?>(null);
  final ValueNotifier<int> frameCountNotifier = ValueNotifier<int>(0);
  final ValueNotifier<DateTime?> lastFrameTimeNotifier =
      ValueNotifier<DateTime?>(null);

  @override
  void initState() {
    super.initState();
    _connectWebSocket();
  }

  void _connectWebSocket() {
    try {
      channel = WebSocketChannel.connect(
        Uri.parse(kWebSocketUrl),
      );

      setState(() {
        isConnected = true;
        messages.add(
          MessageData(
            text: 'Đã kết nối thành công!',
            type: MessageType.system,
            timestamp: DateTime.now(),
          ),
        );
      });

      // Lắng nghe tin nhắn từ WebSocket
      channel!.stream.listen(
        (message) {
          setState(() {
            _processMessage(message.toString());
          });
          _scrollToBottom();
        },
        onError: (error) {
          setState(() {
            isConnected = false;
            messages.add(
              MessageData(
                text: 'Lỗi: $error',
                type: MessageType.system,
                timestamp: DateTime.now(),
              ),
            );
          });
        },
        onDone: () {
          setState(() {
            isConnected = false;
            messages.add(
              MessageData(
                text: 'Kết nối đã đóng',
                type: MessageType.system,
                timestamp: DateTime.now(),
              ),
            );
          });
        },
      );
    } catch (e) {
      setState(() {
        isConnected = false;
        messages.add(
          MessageData(
            text: 'Không thể kết nối: $e',
            type: MessageType.system,
            timestamp: DateTime.now(),
          ),
        );
      });
    }
  }

  void _processMessage(String rawMessage) {
    try {
      // Thử parse JSON
      final jsonData = jsonDecode(rawMessage);

      // Kiểm tra xem có chứa ảnh base64 không
      if (jsonData is Map<String, dynamic>) {
        String? base64Image;

        // Tìm field chứa ảnh base64 (có thể là "image", "data", "frame", etc.)
        for (String key in jsonData.keys) {
          final value = jsonData[key];
          if (value is String && _isBase64Image(value)) {
            base64Image = value;
            break;
          }
        }

        if (base64Image != null) {
          // Giải mã base64 thành ảnh và cập nhật frame hiện tại
          try {
            final imageBytes = base64Decode(base64Image);

            // Cập nhật frame qua ValueNotifier (không rebuild toàn bộ UI)
            currentFrameNotifier.value = imageBytes;
            frameCountNotifier.value = frameCountNotifier.value + 1;
            lastFrameTimeNotifier.value = DateTime.now();

            // Chỉ cập nhật messages khi cần thiết (throttling)
            if (frameCountNotifier.value % 10 == 0) {
              // Chỉ log mỗi 10 frame
              setState(() {
                messages.add(
                  MessageData(
                    text:
                        'Frame #${frameCountNotifier.value} - ${DateTime.now().toString().substring(11, 19)}',
                    type: MessageType.received,
                    timestamp: DateTime.now(),
                  ),
                );
              });
            }
          } catch (e) {
            setState(() {
              messages.add(
                MessageData(
                  text: 'Lỗi giải mã frame: $e',
                  type: MessageType.system,
                  timestamp: DateTime.now(),
                ),
              );
            });
          }
        } else {
          // JSON không chứa ảnh - tin nhắn text thường
          messages.add(
            MessageData(
              text: 'Nhận JSON: ${jsonData.toString()}',
              type: MessageType.received,
              timestamp: DateTime.now(),
            ),
          );
        }
      } else {
        // Không phải JSON object
        messages.add(
          MessageData(
            text: 'Nhận: $rawMessage',
            type: MessageType.received,
            timestamp: DateTime.now(),
          ),
        );
      }
    } catch (e) {
      // Không phải JSON, xử lý như text thường
      messages.add(
        MessageData(
          text: 'Nhận: $rawMessage',
          type: MessageType.received,
          timestamp: DateTime.now(),
        ),
      );
    }
  }

  bool _isBase64Image(String data) {
    // Kiểm tra xem chuỗi có phải là base64 image không
    if (data.length < 100) return false; // Quá ngắn cho một ảnh

    // Kiểm tra pattern base64 và độ dài hợp lý cho ảnh
    final base64RegExp = RegExp(r'^[A-Za-z0-9+/]*={0,2}$');
    return base64RegExp.hasMatch(data) &&
        data.length > 1000; // Ảnh thường > 1KB
  }

  void _sendMessage() {
    if (_controller.text.isNotEmpty && isConnected) {
      final message = _controller.text;
      channel?.sink.add(message);
      setState(() {
        messages.add(
          MessageData(
            text: 'Gửi: $message',
            type: MessageType.sent,
            timestamp: DateTime.now(),
          ),
        );
      });
      _controller.clear();
      _scrollToBottom();
    }
  }

  void _disconnectWebSocket() {
    channel?.sink.close(status.goingAway);
    setState(() {
      isConnected = false;
      messages.add(
        MessageData(
          text: 'Đã ngắt kết nối',
          type: MessageType.system,
          timestamp: DateTime.now(),
        ),
      );
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showFullscreenVideo() {
    if (currentFrameNotifier.value == null) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.black,
          insetPadding: EdgeInsets.zero,
          child: Stack(
            children: [
              // Fullscreen video với ValueListenableBuilder
              Container(
                width: double.infinity,
                height: double.infinity,
                child: ValueListenableBuilder<Uint8List?>(
                  valueListenable: currentFrameNotifier,
                  builder: (context, frameData, child) {
                    if (frameData == null) {
                      return const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      );
                    }
                    return Image.memory(
                      frameData,
                      fit: BoxFit.contain,
                      gaplessPlayback: true, // Quan trọng: Giảm flicker
                    );
                  },
                ),
              ),

              // Close button
              Positioned(
                top: 40,
                right: 20,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white, size: 32),
                ),
              ),

              // Info overlay
              Positioned(
                bottom: 40,
                left: 20,
                child: ValueListenableBuilder<int>(
                  valueListenable: frameCountNotifier,
                  builder: (context, frameCount, child) {
                    return ValueListenableBuilder<DateTime?>(
                      valueListenable: lastFrameTimeNotifier,
                      builder: (context, lastFrameTime, child) {
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Frame #$frameCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (lastFrameTime != null)
                                Text(
                                  'Thời gian: ${lastFrameTime.toString().substring(11, 19)}',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    // Dispose ValueNotifiers để tránh memory leak
    currentFrameNotifier.dispose();
    frameCountNotifier.dispose();
    lastFrameTimeNotifier.dispose();

    // Đóng WebSocket connection và dispose controllers
    channel?.sink.close();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('WebSocket Video Stream'),
        actions: [
          ValueListenableBuilder<Uint8List?>(
            valueListenable: currentFrameNotifier,
            builder: (context, currentFrame, child) {
              if (currentFrame != null) {
                return IconButton(
                  onPressed: () => _showFullscreenVideo(),
                  icon: const Icon(Icons.fullscreen),
                  tooltip: 'Xem video toàn màn hình',
                );
              }
              return const SizedBox.shrink();
            },
          ),
          IconButton(
            onPressed: () {
              setState(() {
                messages.clear();
                // Reset frame data với ValueNotifier
                currentFrameNotifier.value = null;
                frameCountNotifier.value = 0;
                lastFrameTimeNotifier.value = null;
              });
            },
            icon: const Icon(Icons.clear_all),
            tooltip: 'Xóa tất cả',
          ),
          Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isConnected ? Colors.green : Colors.red,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isConnected ? 'Live' : 'Offline',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Thanh thông tin
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey.shade100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ValueListenableBuilder<int>(
                  valueListenable: frameCountNotifier,
                  builder: (context, frameCount, child) {
                    return Text(
                      'Frame: $frameCount | Tin nhắn: ${messages.length}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    );
                  },
                ),
                Text(
                  isConnected ? '🟢 Đang kết nối' : '🔴 Không kết nối',
                  style: TextStyle(
                    fontSize: 12,
                    color: isConnected ? Colors.green : Colors.red,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Khu vực hiển thị video stream
          Expanded(
            flex: 3, // Chiếm 3/5 màn hình
            child: Container(
              width: double.infinity,
              color: Colors.black,
              child: ValueListenableBuilder<Uint8List?>(
                valueListenable: currentFrameNotifier,
                builder: (context, currentFrame, child) {
                  return currentFrame != null
                      ? Image.memory(
                          currentFrame,
                          fit: BoxFit.contain,
                          gaplessPlayback: true, // Quan trọng: Giảm flicker
                          errorBuilder: (context, error, stackTrace) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.error,
                                    color: Colors.red,
                                    size: 48,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Lỗi hiển thị frame',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                            );
                          },
                        )
                      : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.videocam_off,
                                color: Colors.grey,
                                size: 64,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Đang chờ video stream...',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 16,
                                ),
                              ),
                              ValueListenableBuilder<DateTime?>(
                                valueListenable: lastFrameTimeNotifier,
                                builder: (context, lastFrameTime, child) {
                                  if (lastFrameTime != null) {
                                    return Text(
                                      'Frame cuối: ${lastFrameTime.toString().substring(11, 19)}',
                                      style: TextStyle(
                                        color: Colors.grey.shade400,
                                        fontSize: 12,
                                      ),
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                            ],
                          ),
                        );
                },
              ),
            ),
          ),

          // Thanh phân cách
          Container(height: 1, color: Colors.grey.shade300),

          // Khu vực chat (nhỏ hơn)
          Expanded(
            flex: 2, // Chiếm 2/5 màn hình
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  // Header chat
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Icon(Icons.chat, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 8),
                        Text(
                          'Nhật ký kết nối',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Chat messages
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        final isReceived = message.type == MessageType.received;
                        final isSent = message.type == MessageType.sent;
                        final isSystem = message.type == MessageType.system;

                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 2),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isReceived
                                ? Colors.blue.shade50
                                : isSent
                                ? Colors.green.shade50
                                : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              // Timestamp
                              Text(
                                message.timestamp.toString().substring(11, 19),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                              const SizedBox(width: 8),

                              // Message text
                              Expanded(
                                child: Text(
                                  message.text,
                                  style: TextStyle(
                                    color: isSystem
                                        ? Colors.grey.shade600
                                        : Colors.black87,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Khu vực gửi tin nhắn
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        enabled: isConnected,
                        decoration: const InputDecoration(
                          hintText: 'Nhập tin nhắn...',
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: isConnected ? _sendMessage : null,
                      child: const Text('Gửi'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: !isConnected ? _connectWebSocket : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Kết nối'),
                    ),
                    ElevatedButton(
                      onPressed: isConnected ? _disconnectWebSocket : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Ngắt kết nối'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
