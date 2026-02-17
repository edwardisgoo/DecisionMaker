import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firebase_room_service.dart';

class ProposalScreen extends StatefulWidget {
  final String roomCode;

  const ProposalScreen({super.key, required this.roomCode});

  @override
  State<ProposalScreen> createState() => _ProposalScreenState();
}

class _ProposalScreenState extends State<ProposalScreen> {
  final _svc = FirebaseRoomService.instance;
  final TextEditingController _proposalController = TextEditingController();
  bool _loading = false;
  bool _hasSubmitted = false;

  Future<void> _submitProposal(String authorName) async {
    final proposalText = _proposalController.text.trim();

    if (proposalText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a proposal.')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await _svc.submitProposal(
        code: widget.roomCode,
        proposalText: proposalText,
        authorName: authorName,
      );
      if (mounted) {
        setState(() {
          _hasSubmitted = true;
          _loading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Proposal submitted!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Submission failed: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _proposalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Phase 1: Proposals')),
      body: StreamBuilder(
        stream: _svc.roomStream(widget.roomCode),
        builder: (context, roomSnap) {
          if (roomSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!roomSnap.hasData || !(roomSnap.data?.exists ?? false)) {
            return const Center(child: Text('Room not found.'));
          }

          final roomData = roomSnap.data!.data()!;
          final title = (roomData['title'] ?? '') as String;
          final hostUid = (roomData['hostUid'] ?? '') as String;
          final isMeHost = myUid == hostUid;

          return StreamBuilder(
            stream: _svc.participantsStream(widget.roomCode),
            builder: (context, partSnap) {
              if (partSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final participants = partSnap.data?.docs ?? [];

              // Find current user's participant data
              String myName = 'You';
              try {
                final myParticipant = participants.firstWhere((p) => p.id == myUid);
                myName = (myParticipant.data()['name'] ?? 'You') as String;
              } catch (_) {
                // User not found in participants, use default name
              }

              return StreamBuilder(
                stream: _svc.proposalsStream(widget.roomCode),
                builder: (context, proposalSnap) {
                  if (proposalSnap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final proposals = proposalSnap.data?.docs ?? [];
                  final submittedUids =
                      proposals.map((p) => p.id).toSet();

                  // Check if current user has submitted
                  if (submittedUids.contains(myUid) && !_hasSubmitted) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        setState(() => _hasSubmitted = true);
                      }
                    });
                  }

                  final allSubmitted =
                      participants.length == proposals.length &&
                          participants.isNotEmpty;

                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Room Code: ${widget.roomCode}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Submit your proposal for what we should decide on:',
                          style: TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 12),
                        if (!_hasSubmitted) ...[
                          TextField(
                            controller: _proposalController,
                            maxLines: 4,
                            maxLength: 500,
                            decoration: const InputDecoration(
                              labelText: 'Your proposal',
                              hintText:
                                  'e.g., "Let\'s go to the Italian restaurant downtown"',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: _loading
                                ? null
                                : () => _submitProposal(myName),
                            child: Text(
                              _loading ? 'Submitting…' : 'Submit Proposal',
                            ),
                          ),
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              border: Border.all(color: Colors.green),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: Colors.green.shade700,
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text(
                                    'Your proposal has been submitted!',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        const Divider(),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Submission Status',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '${proposals.length}/${participants.length} submitted',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: allSubmitted
                                    ? Colors.green.shade700
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: ListView.builder(
                            itemCount: participants.length,
                            itemBuilder: (context, index) {
                              final p = participants[index].data();
                              final uid = participants[index].id;
                              final name = (p['name'] ?? 'Someone') as String;
                              final isHost = (p['isHost'] ?? false) as bool;
                              final hasSubmitted = submittedUids.contains(uid);

                              return ListTile(
                                leading: Icon(
                                  isHost ? Icons.star : Icons.person,
                                  color: isHost ? Colors.amber : null,
                                ),
                                title: Text(name),
                                subtitle: Text(uid == myUid ? 'You' : ''),
                                trailing: hasSubmitted
                                    ? Icon(
                                        Icons.check_circle,
                                        color: Colors.green.shade700,
                                      )
                                    : Icon(
                                        Icons.hourglass_empty,
                                        color: Colors.grey.shade400,
                                      ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (isMeHost)
                          FilledButton(
                            onPressed: allSubmitted
                                ? () {
                                    // TODO: Navigate to Phase 2 (Voting)
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Phase 2 not yet implemented',
                                        ),
                                      ),
                                    );
                                  }
                                : null,
                            child: Text(
                              allSubmitted
                                  ? 'Host: Continue to Next Phase'
                                  : 'Host: Waiting for all submissions…',
                            ),
                          )
                        else
                          FilledButton(
                            onPressed: null,
                            child: Text(
                              allSubmitted
                                  ? 'Waiting for host to continue…'
                                  : 'Waiting for submissions…',
                            ),
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
