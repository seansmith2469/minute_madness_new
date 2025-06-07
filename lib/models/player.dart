class Player {
  final String name;
  Duration? time;
  Duration? error;

  Player(this.name, {this.time, this.error});

  bool get hasPlayed => time != null && error != null;
}
