import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timex/screens/chat/add-member/add_members_screen.dart';
import '../../../widgets/text/text.dart';
import '../model/chat_models.dart';
import '../services/chat_service.dart';

class GroupManagementScreen extends StatefulWidget {
  final ChatRoom chatRoom;

  const GroupManagementScreen({Key? key, required this.chatRoom}) : super(key: key);

  @override
  State<GroupManagementScreen> createState() => _GroupManagementScreenState();
}

class _GroupManagementScreenState extends State<GroupManagementScreen> {
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _groupDescriptionController = TextEditingController();
  bool _isLoading = false;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _groupNameController.text = widget.chatRoom.name;
    _groupDescriptionController.text = widget.chatRoom.description ?? '';
    _checkAdminStatus();
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    _groupDescriptionController.dispose();
    super.dispose();
  }

  void _checkAdminStatus() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _isAdmin = widget.chatRoom.createdBy == currentUserId;
  }

  Future<void> _updateGroupInfo() async {
    if (_groupNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: txt(
            'Group name cannot be empty',
            style: TxtStl.bodyText2(color: Colors.white),
          ),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ChatService.updateGroupInfo(
        widget.chatRoom.id,
        name: _groupNameController.text.trim(),
        description: _groupDescriptionController.text.trim(),
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: txt(
              'Group info updated successfully',
              style: TxtStl.bodyText2(color: Colors.white),
            ),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating group info: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _removeMember(String userId) async {
    // Check if current user is admin
    if (!_isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only group admins can remove members')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: txt(
          'Remove Member',
          style: TxtStl.titleText2(
            color: const Color(0xFF1E293B),
            fontWeight: FontWeight.w600,
          ),
        ),
        content: txt(
          'Are you sure you want to remove this member from the group?',
          style: TxtStl.bodyText2(
            color: const Color(0xFF64748B),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: txt(
              'Cancel',
              style: TxtStl.bodyText1(
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFEF4444)),
            child: txt(
              'Remove',
              style: TxtStl.bodyText1(
                color: const Color(0xFFEF4444),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      // Use the enhanced method that sends system messages
      await ChatService.removeMemberFromGroup(widget.chatRoom.id, userId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Member removed successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error removing member: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addMembers() async {
    // Check if current user is admin
    if (!_isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only group admins can add members')),
      );
      return;
    }

    // Get the current participants from the latest stream data
    final chatRoomStream = ChatService.getChatRoomStream(widget.chatRoom.id);
    final currentChatRoom = await chatRoomStream.first;
    if (currentChatRoom == null) return;

    final participants = await ChatService.getParticipantProfiles(currentChatRoom.participants);

    final result = await Navigator.push<List<UserProfile>>(
      context,
      MaterialPageRoute(
        builder: (context) => AddMembersScreen(
          chatRoom: currentChatRoom,
          currentParticipants: participants,
        ),
      ),
    );

    if (result != null && result.isNotEmpty) {
      setState(() => _isLoading = true);
      try {
        final participantIds = result.map((user) => user.id).toList();
        // Use the enhanced method that sends system messages
        await ChatService.addMembersToGroup(widget.chatRoom.id, participantIds);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Members added successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error adding members: $e')),
          );
        }
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _leaveGroup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: txt(
          'Leave Group',
          style: TxtStl.titleText2(
            color: const Color(0xFF1E293B),
            fontWeight: FontWeight.w600,
          ),
        ),
        content: txt(
          'Are you sure you want to leave this group?',
          style: TxtStl.bodyText2(
            color: const Color(0xFF64748B),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: txt(
              'Cancel',
              style: TxtStl.bodyText1(
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFEF4444)),
            child: txt(
              'Leave',
              style: TxtStl.bodyText1(
                color: const Color(0xFFEF4444),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId != null) {
        await ChatService.removeFromGroup(widget.chatRoom.id, currentUserId);
        
        if (mounted) {
          Navigator.popUntil(context, (route) => route.isFirst);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Left group successfully')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error leaving group: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
        title: txt(
          'Group Info',
          style: TxtStl.titleText2(
            color: const Color(0xFF1E293B),
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (_isAdmin)
            Container(
              margin: const EdgeInsets.only(right: 8),
              child: TextButton(
                onPressed: _isLoading ? null : _updateGroupInfo,
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: txt(
                  'Save',
                  style: TxtStl.bodyText1(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Group Info Section
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF3B82F6),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.info_outline,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 12),
                            txt(
                              'Group Information',
                              style: TxtStl.titleText2(
                                color: const Color(0xFF1E293B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _groupNameController,
                          decoration: InputDecoration(
                            labelText: 'Group Name',
                            labelStyle: TxtStl.bodyText2(color: const Color(0xFF64748B)),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
                            ),
                            disabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            filled: true,
                            fillColor: _isAdmin ? const Color(0xFFF8FAFC) : const Color(0xFFF1F5F9),
                          ),
                          enabled: _isAdmin,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _groupDescriptionController,
                          decoration: InputDecoration(
                            labelText: 'Description',
                            labelStyle: TxtStl.bodyText2(color: const Color(0xFF64748B)),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
                            ),
                            disabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            filled: true,
                            fillColor: _isAdmin ? const Color(0xFFF8FAFC) : const Color(0xFFF1F5F9),
                          ),
                          maxLines: 3,
                          enabled: _isAdmin,
                        ),
                        if (!_isAdmin) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.info,
                                  color: Color(0xFFD97706),
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: txt(
                                    'Only group admins can edit group information',
                                    style: TxtStl.bodyText3(
                                      color: const Color(0xFFD97706),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Members Section
                  StreamBuilder<ChatRoom?>(
                    stream: ChatService.getChatRoomStream(widget.chatRoom.id),
                    builder: (context, chatRoomSnapshot) {
                      final currentChatRoom = chatRoomSnapshot.data ?? widget.chatRoom;
                      
                      return StreamBuilder<List<UserProfile>>(
                        stream: ChatService.getParticipantProfilesStream(currentChatRoom.participants),
                        builder: (context, participantsSnapshot) {
                          if (participantsSnapshot.connectionState == ConnectionState.waiting) {
                            return Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
                                ),
                              ),
                            );
                          }
                          
                          final participants = participantsSnapshot.data ?? [];
                          
                          return Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF8B5CF6),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Icon(
                                            Icons.group,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        txt(
                                          'Members (${participants.length})',
                                          style: TxtStl.titleText2(
                                            color: const Color(0xFF1E293B),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (_isAdmin)
                                      TextButton.icon(
                                        onPressed: _addMembers,
                                        style: TextButton.styleFrom(
                                          backgroundColor: const Color(0xFF10B981).withOpacity(0.1),
                                          foregroundColor: const Color(0xFF10B981),
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                        icon: const Icon(Icons.person_add, size: 16),
                                        label: txt(
                                          'Add',
                                          style: TxtStl.bodyText3(
                                            color: const Color(0xFF10B981),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: participants.length,
                                  itemBuilder: (context, index) {
                                    final participant = participants[index];
                                    final isCurrentUser = participant.id == FirebaseAuth.instance.currentUser?.uid;
                                    final isCreator = participant.id == currentChatRoom.createdBy;

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: isCurrentUser 
                                            ? const Color(0xFF8B5CF6).withOpacity(0.08)
                                            : const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isCurrentUser 
                                              ? const Color(0xFF8B5CF6).withOpacity(0.2)
                                              : const Color(0xFFE2E8F0),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Stack(
                                            children: [
                                              Container(
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: isCreator 
                                                        ? const Color(0xFFF59E0B)
                                                        : isCurrentUser 
                                                            ? const Color(0xFF8B5CF6)
                                                            : Colors.transparent,
                                                    width: 2,
                                                  ),
                                                ),
                                                child: CircleAvatar(
                                                  radius: 20,
                                                  backgroundImage: participant.photoURL != null && participant.photoURL!.isNotEmpty
                                                      ? NetworkImage(participant.photoURL!)
                                                      : null,
                                                  backgroundColor: const Color(0xFF8B5CF6),
                                                  child: participant.photoURL == null || participant.photoURL!.isEmpty
                                                      ? txt(
                                                          participant.displayName.isNotEmpty
                                                              ? participant.displayName[0].toUpperCase()
                                                              : 'U',
                                                          style: TxtStl.bodyText1(
                                                            color: Colors.white,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        )
                                                      : null,
                                                ),
                                              ),
                                              if (participant.isOnline)
                                                Positioned(
                                                  bottom: 0,
                                                  right: 0,
                                                  child: Container(
                                                    width: 12,
                                                    height: 12,
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFF10B981),
                                                      shape: BoxShape.circle,
                                                      border: Border.all(color: Colors.white, width: 2),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: txt(
                                                        isCurrentUser 
                                                            ? '${participant.displayName} (You)'
                                                            : participant.displayName,
                                                        style: TxtStl.bodyText1(
                                                          color: const Color(0xFF1E293B),
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      ),
                                                    ),
                                                    if (isCreator)
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                        decoration: BoxDecoration(
                                                          color: const Color(0xFFF59E0B),
                                                          borderRadius: BorderRadius.circular(12),
                                                        ),
                                                        child: txt(
                                                          'Admin',
                                                          style: TxtStl.labelText1(
                                                            color: Colors.white,
                                                            fontSize: 10,
                                                            fontWeight: FontWeight.w600,
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                                const SizedBox(height: 2),
                                                txt(
                                                  participant.email ?? 'No email',
                                                  style: TxtStl.bodyText3(
                                                    color: const Color(0xFF64748B),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (_isAdmin && !isCurrentUser && !isCreator)
                                            Container(
                                              margin: const EdgeInsets.only(left: 8),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFEF4444).withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: IconButton(
                                                onPressed: () => _removeMember(participant.id),
                                                icon: const Icon(
                                                  Icons.remove_circle_outline,
                                                  color: Color(0xFFEF4444),
                                                  size: 18,
                                                ),
                                                padding: const EdgeInsets.all(8),
                                                constraints: const BoxConstraints(),
                                              ),
                                            ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // Danger Zone
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFEF4444).withOpacity(0.2),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.warning_outlined,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 12),
                            txt(
                              'Danger Zone',
                              style: TxtStl.titleText2(
                                color: const Color(0xFFEF4444),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _leaveGroup,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFEF4444),
                              side: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
                              backgroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.exit_to_app, size: 18),
                            label: txt(
                              'Leave Group',
                              style: TxtStl.bodyText1(
                                color: const Color(0xFFEF4444),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFED7D7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.info,
                                color: Color(0xFFDC2626),
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: txt(
                                  'Once you leave this group, you will no longer receive messages and won\'t be able to rejoin unless added by an admin.',
                                  style: TxtStl.bodyText3(
                                    color: const Color(0xFFDC2626),
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 3,
                                  overflow: TextOverflow.visible,
                                  softWrap: true,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
