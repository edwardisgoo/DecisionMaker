import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firebase_room_service.dart';

class VotingScreen extends StatefulWidget {
  final String roomCode;

  const VotingScreen({super.key, required this.roomCode});

  @override
  State<VotingScreen> createState() => _VotingScreenState();
}

class _VotingScreenState extends State<VotingScreen> {
  final _svc = FirebaseRoomService.instance;
  final PageController _pageController = PageController();
  final Set<String> _selectedProposalIds = {};
  bool _hasConfirmed = false;
  bool _loading = false;
  int _currentPage = 0;

  Future<void> _submitVotes() async {
    setState(() => _loading = true);
    try {
      await _svc.submitVotes(
        code: widget.roomCode,
        votedProposalIds: _selectedProposalIds.toList(),
      );
      if (mounted) {
        setState(() {
          _hasConfirmed = true;
          _loading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Votes submitted successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit votes: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Phase 2: Voting')),
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
              final voteQuota = _svc.calculateVoteQuota(participants.length);
              final remainingVotes = voteQuota - _selectedProposalIds.length;

              return StreamBuilder(
                stream: _svc.proposalsStream(widget.roomCode),
                builder: (context, proposalSnap) {
                  if (proposalSnap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final proposals = proposalSnap.data?.docs ?? [];

                  if (proposals.isEmpty) {
                    return const Center(
                      child: Text('No proposals to vote on.'),
                    );
                  }

                  return StreamBuilder(
                    stream: _svc.votesStream(widget.roomCode),
                    builder: (context, voteSnap) {
                      if (voteSnap.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }

                      final votes = voteSnap.data?.docs ?? [];
                      final confirmedUids = votes
                          .where((v) =>
                              (v.data()['hasConfirmed'] ?? false) as bool)
                          .map((v) => v.id)
                          .toSet();

                      // Check if current user has confirmed from Firestore
                      if (confirmedUids.contains(myUid) && !_hasConfirmed) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            setState(() => _hasConfirmed = true);
                          }
                        });
                      }

                      final allConfirmed = participants.length == votes.length &&
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
                            // Vote counter chip
                            Chip(
                              avatar: Icon(
                                Icons.how_to_vote,
                                color: remainingVotes > 0
                                    ? Colors.green.shade700
                                    : Colors.grey.shade600,
                              ),
                              label: Text(
                                '$remainingVotes of $voteQuota votes remaining',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              backgroundColor: remainingVotes > 0
                                  ? Colors.green.shade50
                                  : Colors.grey.shade200,
                            ),
                            const SizedBox(height: 16),
                            // Page indicator
                            Text(
                              'Proposal ${_currentPage + 1} of ${proposals.length}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Swipeable cards
                            Expanded(
                              child: PageView.builder(
                                key: const PageStorageKey('voting_page_view'),
                                controller: _pageController,
                                physics: const AlwaysScrollableScrollPhysics(),
                                onPageChanged: (index) {
                                  setState(() => _currentPage = index);
                                },
                                itemCount: proposals.length,
                                itemBuilder: (context, index) {
                                  final proposal = proposals[index];
                                  final proposalData = proposal.data();
                                  final proposalId = proposal.id;
                                  final authorName =
                                      (proposalData['authorName'] ?? 'Someone')
                                          as String;
                                  final proposalText =
                                      (proposalData['text'] ?? '') as String;
                                  final isSelected =
                                      _selectedProposalIds.contains(proposalId);
                                  final canVote =
                                      remainingVotes > 0 || isSelected;

                                  return Padding(
                                    key: ValueKey(proposalId),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    child: Card(
                                    elevation: 4,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(20),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.person,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primary,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  authorName,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleLarge
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 16),
                                          const Divider(),
                                          const SizedBox(height: 16),
                                          Expanded(
                                            child: SingleChildScrollView(
                                              physics: const ClampingScrollPhysics(),
                                              child: Text(
                                                proposalText,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyLarge,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          CheckboxListTile(
                                            title: Text(
                                              isSelected
                                                  ? 'Voted for this proposal'
                                                  : 'Vote for this proposal',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: isSelected
                                                    ? Colors.green.shade700
                                                    : null,
                                              ),
                                            ),
                                            value: isSelected,
                                            enabled: !_hasConfirmed && canVote,
                                            onChanged: _hasConfirmed
                                                ? null
                                                : (bool? value) {
                                                    if (value == true) {
                                                      if (remainingVotes > 0) {
                                                        setState(() {
                                                          _selectedProposalIds
                                                              .add(proposalId);
                                                        });
                                                      } else {
                                                        ScaffoldMessenger.of(
                                                                context)
                                                            .showSnackBar(
                                                          const SnackBar(
                                                            content: Text(
                                                              'No votes remaining!',
                                                            ),
                                                          ),
                                                        );
                                                      }
                                                    } else {
                                                      setState(() {
                                                        _selectedProposalIds
                                                            .remove(proposalId);
                                                      });
                                                    }
                                                  },
                                          ),
                                        ],
                                      ),
                                    ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Confirmation status
                            if (_hasConfirmed)
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
                                        'Your votes have been confirmed!',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              FilledButton(
                                onPressed:
                                    _loading || _hasConfirmed ? null : _submitVotes,
                                child: Text(
                                  _loading
                                      ? 'Submitting...'
                                      : 'Confirm Votes (${_selectedProposalIds.length} selected)',
                                ),
                              ),
                            const SizedBox(height: 12),
                            Text(
                              '${confirmedUids.length}/${participants.length} confirmed their votes',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: allConfirmed
                                    ? Colors.green.shade700
                                    : Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Host controls
                            if (isMeHost && allConfirmed)
                              FilledButton(
                                onPressed: () {
                                  // TODO: Navigate to results screen
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Results screen not yet implemented',
                                      ),
                                    ),
                                  );
                                },
                                child: const Text('Host: Show Voting Results'),
                              )
                            else if (isMeHost)
                              FilledButton(
                                onPressed: null,
                                child: Text(
                                  'Host: Waiting for all votes... (${confirmedUids.length}/${participants.length})',
                                ),
                              )
                            else
                              FilledButton(
                                onPressed: null,
                                child: Text(
                                  allConfirmed
                                      ? 'Waiting for host to show results...'
                                      : 'Waiting for all votes... (${confirmedUids.length}/${participants.length})',
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
          );
        },
      ),
    );
  }
}
