import 'dart:math';

extension DurationExtension on Duration {
  String smallRepr() {
    var days = inDays;
    var hours = inHours % 24;
    var minutes = inMinutes % 60;
    var seconds = inSeconds % 60;

    var daysS = days > 0 ? "${days}d" : "";
    var hoursS = hours > 0 ? "${hours}h" : "";
    var minutesS = minutes > 0 ? "${minutes}m" : "";
    var secondsS = seconds > 0 ? "${seconds}s" : "";

    return "$daysS$hoursS$minutesS$secondsS";
  }

  String bigRepr([int truncation = 0]) {
    var days = inDays;
    var hours = inHours % 24;
    var minutes = inMinutes % 60;
    var seconds = inSeconds % 60;

    var daysS = days > 0 ? "${days} days" : "";
    var hoursS = hours > 0 ? "${hours} hours" : "";
    var minutesS = minutes > 0 ? "${minutes} mins" : "";
    var secondsS = seconds > 0 ? "${seconds} secs" : "";

    var parts =
        [daysS, hoursS, minutesS, secondsS].where((a) => a.isNotEmpty).toList();

    if (truncation > 0) {
      parts = parts.sublist(0, min(truncation, parts.length));
    }

    return parts.join(", ");
  }
}
