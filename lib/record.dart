import 'package:record/record.dart';


void main() async {

final record = AudioRecorder();

// Check and request permission if needed
if (await record.hasPermission()) {
  // Start recording to file
  await record.start(const RecordConfig(), path: 'aFullPath/myFile.m4a');
  // ... or to stream
  final stream = await record.startStream(const RecordConfig(encoder: AudioEncoder.pcm16bits));
}

final path = await record.stop();
await record.cancel();

record.dispose(); 

}