/// Someone you and the other person both liked — a mutual connection
/// ("Sportbuddy"), not yet necessarily a chat. See LikeService.getBuddies.
/// Someone who liked me and whom I haven't liked back yet.
class ReceivedLike {
  ReceivedLike({required this.userId, required this.likedAt, this.activityId});

  final String userId;
  final DateTime likedAt;

  /// Their sport time the like was made for, if any.
  final String? activityId;
}

class Buddy {
  final String userId;
  final DateTime connectedAt;
  final String? activityId;

  Buddy({required this.userId, required this.connectedAt, this.activityId});
}
