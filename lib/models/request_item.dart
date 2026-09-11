class RequestItem {
  RequestItem({
    required this.artist,
    required this.song,
    required this.note,
    required this.username,
    this.votes = 0,
  });

  final String artist;
  final String song;
  final String note;
  final String username;
  int votes;
}
