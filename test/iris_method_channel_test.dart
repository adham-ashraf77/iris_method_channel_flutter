import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:iris_method_channel/src/bindings/native_iris_api_common_bindings.dart';
import 'package:iris_method_channel/src/bindings/native_iris_event_bindings.dart'
    as iris_event;
import 'package:iris_method_channel/src/iris_event.dart';
import 'package:iris_method_channel/src/iris_method_channel.dart';
import 'package:iris_method_channel/src/native_bindings_delegate.dart';
import 'package:iris_method_channel/src/scoped_objects.dart';
import 'dart:ffi' as ffi;

import 'package:test/test.dart';

class _ApiParam {
  _ApiParam(this.event, this.data);
  final String event;
  final String data;
}

class _CallApiRecord {
  _CallApiRecord(this.methodCall, this.apiParam);
  final IrisMethodCall methodCall;
  final _ApiParam apiParam;
}

class _FakeNativeBindingDelegateMessenger {
  _FakeNativeBindingDelegateMessenger() {
    apiCallPort.listen((message) {
      assert(message is _CallApiRecord);
      callApiRecords.add(message);
    });
  }
  final apiCallPort = ReceivePort();
  final callApiRecords = <_CallApiRecord>[];

  SendPort getSendPort() {
    return apiCallPort.sendPort;
  }
}

class _FakeNativeBindingDelegate implements NativeBindingDelegate {
  _FakeNativeBindingDelegate(this.apiCallPortSendPort);

  final SendPort apiCallPortSendPort;

  void _response(ffi.Pointer<ApiParam> param, Map<String, Object> result) {
    using<void>((Arena arena) {
      final ffi.Pointer<Utf8> resultMapPointerUtf8 =
          jsonEncode(result).toNativeUtf8(allocator: arena);
      final ffi.Pointer<ffi.Int8> resultMapPointerInt8 =
          resultMapPointerUtf8.cast();

      for (int i = 0; i < kBasicResultLength; i++) {
        if (i >= resultMapPointerUtf8.length) {
          break;
        }

        param.ref.result[i] = resultMapPointerInt8[i];
      }
    });
  }

  @override
  int callApi(IrisMethodCall methodCall, ffi.Pointer<ffi.Void> apiEnginePtr,
      ffi.Pointer<ApiParam> param) {
    final record = _CallApiRecord(
      methodCall,
      _ApiParam(
        param.ref.event.cast<Utf8>().toDartString(),
        param.ref.data.cast<Utf8>().toDartString(),
      ),
    );
    apiCallPortSendPort.send(record);

    _response(param, {});

    return 0;
  }

  @override
  ffi.Pointer<ffi.Void> createIrisEventHandler(
      ffi.Pointer<IrisCEventHandler> eventHandler) {
    final record = _CallApiRecord(
      const IrisMethodCall('createIrisEventHandler', '{}'),
      _ApiParam(
        'createIrisEventHandler',
        '{}',
      ),
    );
    apiCallPortSendPort.send(record);
    return ffi.Pointer<ffi.Void>.fromAddress(123456);
  }

  @override
  ffi.Pointer<ffi.Void> createNativeApiEngine(
      List<ffi.Pointer<ffi.Void>> args) {
    return ffi.Pointer<ffi.Void>.fromAddress(0);
  }

  @override
  void destroyIrisEventHandler(ffi.Pointer<ffi.Void> handler) {
    final record = _CallApiRecord(
      const IrisMethodCall('destroyIrisEventHandler', '{}'),
      _ApiParam(
        'destroyIrisEventHandler',
        '{}',
      ),
    );
    apiCallPortSendPort.send(record);
  }

  @override
  void destroyNativeApiEngine(ffi.Pointer<ffi.Void> apiEnginePtr) {
    final record = _CallApiRecord(
      const IrisMethodCall('destroyNativeApiEngine', '{}'),
      _ApiParam(
        'destroyNativeApiEngine',
        '{}',
      ),
    );
    apiCallPortSendPort.send(record);
  }

  @override
  void initialize() {
    final record = _CallApiRecord(
      const IrisMethodCall('initialize', '{}'),
      _ApiParam(
        'initialize',
        '{}',
      ),
    );
    apiCallPortSendPort.send(record);
  }
}

class _FakeIrisEvent implements IrisEvent {
  _FakeIrisEvent(this.apiCallPortSendPort);

  final SendPort apiCallPortSendPort;

  @override
  void initialize() {
    final record = _CallApiRecord(
      const IrisMethodCall('IrisEvent_initialize', '{}'),
      _ApiParam(
        'IrisEvent_initialize',
        '{}',
      ),
    );
    apiCallPortSendPort.send(record);
  }

  @override
  void registerEventHandler(SendPort sendPort) {
    final record = _CallApiRecord(
      const IrisMethodCall('IrisEvent_registerEventHandler', '{}'),
      _ApiParam(
        'IrisEvent_registerEventHandler',
        '{}',
      ),
    );
    apiCallPortSendPort.send(record);
  }

  @override
  void unregisterEventHandler(SendPort sendPort) {
    final record = _CallApiRecord(
      const IrisMethodCall('IrisEvent_unregisterEventHandler', '{}'),
      _ApiParam(
        'IrisEvent_unregisterEventHandler',
        '{}',
      ),
    );
    apiCallPortSendPort.send(record);
  }

  @override
  void dispose() {
    final record = _CallApiRecord(
      const IrisMethodCall('IrisEvent_dispose', '{}'),
      _ApiParam(
        'IrisEvent_dispose',
        '{}',
      ),
    );
    apiCallPortSendPort.send(record);
  }

  @override
  ffi.Pointer<
          ffi.NativeFunction<
              ffi.Void Function(ffi.Pointer<iris_event.EventParam> p1)>>
      get onEventPtr => ffi.Pointer<
          ffi.NativeFunction<
              ffi.Void Function(
                  ffi.Pointer<iris_event.EventParam> p1)>>.fromAddress(0);
}

class _FakeNativeBindingDelegateProvider extends NativeBindingsProvider {
  _FakeNativeBindingDelegateProvider(
      this.nativeBindingDelegate, this.irisEvent);

  final NativeBindingDelegate nativeBindingDelegate;
  final IrisEvent irisEvent;

  @override
  NativeBindingDelegate provideNativeBindingDelegate() {
    return nativeBindingDelegate;
  }

  @override
  IrisEvent provideIrisEvent() {
    return irisEvent;
  }
}

class _TestEventLoopEventHandler extends EventLoopEventHandler {
  @override
  bool handleEventInternal(
      String eventName, String eventData, List<Uint8List> buffers) {
    return true;
  }
}

void main() {
  late _FakeNativeBindingDelegateMessenger messenger;
  late NativeBindingsProvider nativeBindingsProvider;

  setUp(() {
    messenger = _FakeNativeBindingDelegateMessenger();
    final _FakeNativeBindingDelegate nativeBindingDelegate =
        _FakeNativeBindingDelegate(messenger.getSendPort());
    final _FakeIrisEvent irisEvent = _FakeIrisEvent(messenger.getSendPort());
    nativeBindingsProvider =
        _FakeNativeBindingDelegateProvider(nativeBindingDelegate, irisEvent);
  });

  test('invokeMethod', () async {
    final irisMethodChannel = IrisMethodChannel();
    await irisMethodChannel.initilize(nativeBindingsProvider);
    final callApiResult = await irisMethodChannel
        .invokeMethod(const IrisMethodCall('a_func_name', 'params'));
    expect(callApiResult.irisReturnCode, 0);
    expect(callApiResult.data, {});

    await irisMethodChannel.dispose();
  });

  test('registerEventHandler', () async {
    final irisMethodChannel = IrisMethodChannel();
    await irisMethodChannel.initilize(nativeBindingsProvider);

    const key = TypedScopedKey(_TestEventLoopEventHandler);
    final eventHandler = _TestEventLoopEventHandler();
    await irisMethodChannel.registerEventHandler(
        ScopedEvent(
            scopedKey: key,
            registerName: 'registerEventHandler',
            unregisterName: 'unregisterEventHandler',
            handler: eventHandler),
        jsonEncode({}));

    final holder =
        irisMethodChannel.scopedEventHandlers.get(key) as EventHandlerHolder;
    expect(holder.nativeEventHandlerIntPtr, 123456);

    expect(holder.getEventHandlers().length, 1);
    expect(holder.getEventHandlers().elementAt(0), eventHandler);

    final registerEventHandlerCallRecord = messenger.callApiRecords
        .where((e) => e.methodCall.funcName == 'registerEventHandler');
    expect(registerEventHandlerCallRecord.length, 1);

    await irisMethodChannel.dispose();
  });

  test('unregisterEventHandler', () async {
    final _FakeNativeBindingDelegateMessenger messenger =
        _FakeNativeBindingDelegateMessenger();
    final _FakeNativeBindingDelegate nativeBindingDelegate =
        _FakeNativeBindingDelegate(
      messenger.getSendPort(),
    );
    final _FakeIrisEvent irisEvent = _FakeIrisEvent(messenger.getSendPort());
    final NativeBindingsProvider nativeBindingsProvider =
        _FakeNativeBindingDelegateProvider(nativeBindingDelegate, irisEvent);

    final irisMethodChannel = IrisMethodChannel();
    await irisMethodChannel.initilize(nativeBindingsProvider);

    const key = TypedScopedKey(_TestEventLoopEventHandler);
    final eventHandler = _TestEventLoopEventHandler();
    await irisMethodChannel.registerEventHandler(
        ScopedEvent(
            scopedKey: key,
            registerName: 'registerEventHandler',
            unregisterName: 'unregisterEventHandler',
            handler: eventHandler),
        jsonEncode({}));
    await irisMethodChannel.unregisterEventHandler(
        ScopedEvent(
            scopedKey: key,
            registerName: 'registerEventHandler',
            unregisterName: 'unregisterEventHandler',
            handler: eventHandler),
        jsonEncode({}));

    final holder =
        irisMethodChannel.scopedEventHandlers.get(key) as EventHandlerHolder?;
    expect(holder, isNull);

    final registerEventHandlerCallRecord = messenger.callApiRecords
        .where((e) => e.methodCall.funcName == 'unregisterEventHandler');
    expect(registerEventHandlerCallRecord.length, 1);

    await irisMethodChannel.dispose();
  });

  test('unregisterEventHandlers', () async {
    final _FakeNativeBindingDelegateMessenger messenger =
        _FakeNativeBindingDelegateMessenger();
    final _FakeNativeBindingDelegate nativeBindingDelegate =
        _FakeNativeBindingDelegate(
      messenger.getSendPort(),
    );
    final _FakeIrisEvent irisEvent = _FakeIrisEvent(messenger.getSendPort());
    final NativeBindingsProvider nativeBindingsProvider =
        _FakeNativeBindingDelegateProvider(nativeBindingDelegate, irisEvent);

    final irisMethodChannel = IrisMethodChannel();
    await irisMethodChannel.initilize(nativeBindingsProvider);

    const key = TypedScopedKey(_TestEventLoopEventHandler);
    final eventHandler = _TestEventLoopEventHandler();
    await irisMethodChannel.registerEventHandler(
        ScopedEvent(
            scopedKey: key,
            registerName: 'registerEventHandler',
            unregisterName: 'unregisterEventHandler',
            handler: eventHandler),
        jsonEncode({}));
    await irisMethodChannel.unregisterEventHandlers(key);

    final holder =
        irisMethodChannel.scopedEventHandlers.get(key) as EventHandlerHolder?;
    expect(holder, isNull);

    final registerEventHandlerCallRecord = messenger.callApiRecords
        .where((e) => e.methodCall.funcName == 'unregisterEventHandler');
    expect(registerEventHandlerCallRecord.length, 1);

    await irisMethodChannel.dispose();
  });

  test('registerEventHandler 2 times', () async {
    final irisMethodChannel = IrisMethodChannel();
    await irisMethodChannel.initilize(nativeBindingsProvider);

    const key = TypedScopedKey(_TestEventLoopEventHandler);
    final eventHandler1 = _TestEventLoopEventHandler();
    final eventHandler2 = _TestEventLoopEventHandler();
    await irisMethodChannel.registerEventHandler(
        ScopedEvent(
            scopedKey: key,
            registerName: 'registerEventHandler',
            unregisterName: 'unregisterEventHandler',
            handler: eventHandler1),
        jsonEncode({}));
    await irisMethodChannel.registerEventHandler(
        ScopedEvent(
            scopedKey: key,
            registerName: 'registerEventHandler',
            unregisterName: 'unregisterEventHandler',
            handler: eventHandler2),
        jsonEncode({}));

    final holder =
        irisMethodChannel.scopedEventHandlers.get(key) as EventHandlerHolder;
    expect(holder.nativeEventHandlerIntPtr, 123456);

    expect(holder.getEventHandlers().length, 2);
    expect(holder.getEventHandlers().elementAt(0), eventHandler1);
    expect(holder.getEventHandlers().elementAt(1), eventHandler2);

    final registerEventHandlerCallRecord = messenger.callApiRecords
        .where((e) => e.methodCall.funcName == 'registerEventHandler');
    expect(registerEventHandlerCallRecord.length, 1);

    await irisMethodChannel.dispose();
  });

  test('registerEventHandler 2 times, then unregisterEventHandler', () async {
    final irisMethodChannel = IrisMethodChannel();
    await irisMethodChannel.initilize(nativeBindingsProvider);

    const key = TypedScopedKey(_TestEventLoopEventHandler);
    final eventHandler1 = _TestEventLoopEventHandler();
    final eventHandler2 = _TestEventLoopEventHandler();
    await irisMethodChannel.registerEventHandler(
        ScopedEvent(
            scopedKey: key,
            registerName: 'registerEventHandler',
            unregisterName: 'unregisterEventHandler',
            handler: eventHandler1),
        jsonEncode({}));
    await irisMethodChannel.registerEventHandler(
        ScopedEvent(
            scopedKey: key,
            registerName: 'registerEventHandler',
            unregisterName: 'unregisterEventHandler',
            handler: eventHandler2),
        jsonEncode({}));

    final holder =
        irisMethodChannel.scopedEventHandlers.get(key) as EventHandlerHolder;
    expect(holder.nativeEventHandlerIntPtr, 123456);

    expect(holder.getEventHandlers().length, 2);
    expect(holder.getEventHandlers().elementAt(0), eventHandler1);
    expect(holder.getEventHandlers().elementAt(1), eventHandler2);

    final registerEventHandlerCallRecord = messenger.callApiRecords
        .where((e) => e.methodCall.funcName == 'registerEventHandler');
    expect(registerEventHandlerCallRecord.length, 1);

    await irisMethodChannel.dispose();
  });

  test('registerEventHandler 2 times, then unregisterEventHandlers', () async {
    final irisMethodChannel = IrisMethodChannel();
    await irisMethodChannel.initilize(nativeBindingsProvider);

    const key = TypedScopedKey(_TestEventLoopEventHandler);
    final eventHandler1 = _TestEventLoopEventHandler();
    final eventHandler2 = _TestEventLoopEventHandler();
    await irisMethodChannel.registerEventHandler(
        ScopedEvent(
            scopedKey: key,
            registerName: 'registerEventHandler',
            unregisterName: 'unregisterEventHandler',
            handler: eventHandler1),
        jsonEncode({}));
    await irisMethodChannel.registerEventHandler(
        ScopedEvent(
            scopedKey: key,
            registerName: 'registerEventHandler',
            unregisterName: 'unregisterEventHandler',
            handler: eventHandler2),
        jsonEncode({}));

    await irisMethodChannel.unregisterEventHandlers(key);

    final holder =
        irisMethodChannel.scopedEventHandlers.get(key) as EventHandlerHolder?;
    expect(holder, isNull);

    final registerEventHandlerCallRecord = messenger.callApiRecords
        .where((e) => e.methodCall.funcName == 'unregisterEventHandler');
    expect(registerEventHandlerCallRecord.length, 2);

    await irisMethodChannel.dispose();
  });

  test('Should clean native resources when hot restart happen', () async {
    final irisMethodChannel = IrisMethodChannel();
    await irisMethodChannel.initilize(nativeBindingsProvider);

    irisMethodChannel.workerIsolate.kill(priority: Isolate.immediate);
    // Delayed 1 second to ensure `irisMethodChannel.workerIsolate.kill` done
    await Future.delayed(const Duration(seconds: 1));

    final destroyNativeApiEngineCallRecord = messenger.callApiRecords
        .where((e) => e.methodCall.funcName == 'destroyNativeApiEngine');
    expect(destroyNativeApiEngineCallRecord.length, 1);

    final destroyIrisEventHandlerCallRecord = messenger.callApiRecords
        .where((e) => e.methodCall.funcName == 'destroyIrisEventHandler');
    expect(destroyIrisEventHandlerCallRecord.length, 1);

    final irisEventDisposeCallRecord = messenger.callApiRecords
        .where((e) => e.methodCall.funcName == 'IrisEvent_dispose');
    expect(irisEventDisposeCallRecord.length, 1);
  });

  test('addHotRestartListener', () async {
    final irisMethodChannel = IrisMethodChannel();
    await irisMethodChannel.initilize(nativeBindingsProvider);

    bool hotRestartListenerCalled = false;
    irisMethodChannel.addHotRestartListener((message) {
      hotRestartListenerCalled = true;
    });
    irisMethodChannel.workerIsolate.kill(priority: Isolate.immediate);

    // Delayed 1 second to ensure `irisMethodChannel.workerIsolate.kill` done
    await Future.delayed(const Duration(seconds: 1));

    expect(hotRestartListenerCalled, true);
  });

  test('removeHotRestartListener', () async {
    final irisMethodChannel = IrisMethodChannel();
    await irisMethodChannel.initilize(nativeBindingsProvider);

    bool hotRestartListenerCalled = false;
    // ignore: prefer_function_declarations_over_variables
    final listener = (message) {
      hotRestartListenerCalled = true;
    };
    irisMethodChannel.addHotRestartListener(listener);
    irisMethodChannel.removeHotRestartListener(listener);
    irisMethodChannel.workerIsolate.kill(priority: Isolate.immediate);

    // Delayed 1 second to ensure `irisMethodChannel.workerIsolate.kill` done
    await Future.delayed(const Duration(seconds: 1));

    expect(hotRestartListenerCalled, false);
  });

  test('removeHotRestartListener through returned VoidCallback', () async {
    final irisMethodChannel = IrisMethodChannel();
    await irisMethodChannel.initilize(nativeBindingsProvider);

    bool hotRestartListenerCalled = false;
    // ignore: prefer_function_declarations_over_variables
    final listener = (message) {
      hotRestartListenerCalled = true;
    };
    final removeListener = irisMethodChannel.addHotRestartListener(listener);
    removeListener();
    irisMethodChannel.workerIsolate.kill(priority: Isolate.immediate);

    // Delayed 1 second to ensure `irisMethodChannel.workerIsolate.kill` done
    await Future.delayed(const Duration(seconds: 1));

    expect(hotRestartListenerCalled, false);
  });
}
