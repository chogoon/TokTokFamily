/// `POST /families/kids` 응답 — 새 아이 멤버와 함께 생긴 1:1 방 id.
class AddedKid {
  const AddedKid({required this.memberId, required this.kidRoomId});

  final String memberId;
  final String kidRoomId;

  factory AddedKid.fromJson(Map<String, dynamic> json) {
    return AddedKid(
      memberId: json['memberId'] as String,
      kidRoomId: json['kidRoomId'] as String,
    );
  }
}
