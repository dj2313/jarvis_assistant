import '../tools/friday_tool.dart';
import '../tools/open_app_tool.dart';
import '../tools/send_message_tool.dart';
import '../tools/web_search_tool.dart';
import '../tools/memory_save_tool.dart';
import '../tools/memory_search_tool.dart';
import '../tools/current_time_tool.dart';
import '../tools/battery_tool.dart';
import '../tools/navigation_tool.dart';
import '../tools/get_location_tool.dart';
import '../tools/weather_tool.dart';
import '../services/location_service.dart';

/// Centralized tool factory.
/// Returns the canonical set of tools registered against the Groq tool-calling
/// interface and the local ToolRegistry. Add new tools here only.
List<FridayTool> buildDefaultTools() {
  final locationService = LocationService();

  return [
    CurrentTimeTool(),
    BatteryTool(),
    NavigationTool(locationService: locationService),
    GetLocationTool(locationService: locationService),
    WeatherTool(
      defaultLatitude: () async {
        final pos = await locationService.getCurrentPosition();
        return pos?.latitude;
      },
      defaultLongitude: () async {
        final pos = await locationService.getCurrentPosition();
        return pos?.longitude;
      },
    ),
    OpenAppTool(),
    SendMessageTool(),
    WebSearchTool(),
    MemorySearchTool(),
    MemorySaveTool(),
  ];
}
