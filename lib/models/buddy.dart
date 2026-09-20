/// Someone you and the other person both liked — a mutual connection
/// ("Sportbuddy"), not yet necessarily a chat. See LikeService.getBuddies.
class Buddy {
  final String userId;
  final DateTime connectedAt;
  final String? activityId;

  Buddy({required this.userId, required this.connectedAt, this.activityId});
}
