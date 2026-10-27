import 'live_tracking_socket_contract.dart';
import 'live_tracking_socket_connector_stub.dart'
    if (dart.library.io) 'live_tracking_socket_connector_io.dart'
    if (dart.library.html) 'live_tracking_socket_connector_web.dart'
    as platform;

export 'live_tracking_socket_contract.dart';

LiveTrackingSocketConnector createDefaultLiveTrackingSocketConnector() =>
    platform.createLiveTrackingSocketConnector();
