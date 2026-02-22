import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';
import '../services/firebase_room_service.dart';
import 'voting_screen.dart';

class ResultsScreen extends StatefulWidget {
  final String roomCode;

  const ResultsScreen({super.key, required this.roomCode});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen>
    with TickerProviderStateMixin {
  final _svc = FirebaseRoomService.instance;

  late Stream<
    ({
      DocumentSnapshot<Map<String, dynamic>> room,
      QuerySnapshot<Map<String, dynamic>> participants,
      QuerySnapshot<Map<String, dynamic>> proposals,
      QuerySnapshot<Map<String, dynamic>> votes,
      QuerySnapshot<Map<String, dynamic>> tiebreaker,
    })
  >
  _combinedStream;

  bool _hasChosenTieBreaker = false;
  bool _animationStarted = false;
  bool _animationDone = false;

  // Shuffle & reveal animation state
  AnimationController? _shuffleController;
  Timer? _shuffleTimer;
  int _displayedIndex = 0;
  List<_TallyEntry> _tiedEntries = [];

  @override
  void initState() {
    super.initState();

    final roomStream = _svc.roomStream(widget.roomCode);
    final participantsStream = _svc.participantsStream(widget.roomCode);
    final proposalsStream = _svc.proposalsStream(widget.roomCode);
    final votesStream = _svc.votesStream(widget.roomCode);
    final tieBreakerStream = _svc.tieBreakerStream(widget.roomCode);

    _combinedStream = Rx.combineLatest5(
      roomStream,
      participantsStream,
      proposalsStream,
      votesStream,
      tieBreakerStream,
      (room, participants, proposals, votes, tiebreaker) => (
        room: room,
        participants: participants,
        proposals: proposals,
        votes: votes,
        tiebreaker: tiebreaker,
      ),
    );
  }

  @override
  void dispose() {
    _shuffleController?.dispose();
    _shuffleTimer?.cancel();
    super.dispose();
  }

  void _startShuffleAnimation(List<_TallyEntry> tied, String winnerId) {
    if (_animationStarted) return;
    _animationStarted = true;
    _tiedEntries = tied;

    _shuffleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    );

    // Start cycling through names rapidly, then slow down
    int cycleCount = 0;
    const totalCycles = 25;

    void nextCycle() {
      if (cycleCount >= totalCycles) {
        // Land on the winner
        final winnerIndex = _tiedEntries.indexWhere(
          (e) => e.proposalId == winnerId,
        );
        setState(() {
          _displayedIndex = winnerIndex >= 0 ? winnerIndex : 0;
          _animationDone = true;
        });
        _shuffleTimer?.cancel();
        return;
      }

      setState(() {
        _displayedIndex = cycleCount % _tiedEntries.length;
      });
      cycleCount++;

      // Interval increases as we approach the end (slowing down effect)
      final progress = cycleCount / totalCycles;
      final delay = Duration(
        milliseconds: (60 + (400 * progress * progress)).round(),
      );
      _shuffleTimer = Timer(delay, nextCycle);
    }

    nextCycle();
  }

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Vote Results')),
      body: StreamBuilder(
        stream: _combinedStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: Text('Loading results...'));
          }

          final data = snapshot.data!;
          final roomSnap = data.room;
          final partSnap = data.participants;
          final proposalSnap = data.proposals;
          final voteSnap = data.votes;
          final tbSnap = data.tiebreaker;

          if (!roomSnap.exists) {
            return const Center(child: Text('Room not found.'));
          }

          final roomData = roomSnap.data()!;
          final title = (roomData['title'] ?? '') as String;
          final hostUid = (roomData['hostUid'] ?? '') as String;
          final isMeHost = myUid == hostUid;
          final phase = (roomData['phase'] ?? 'results') as String;
          final randomWinnerId = roomData['randomWinnerId'] as String?;
          final currentRound = (roomData['voteRound'] ?? 1) as int;

          // Navigate back to voting if host triggers a revote
          if (phase == 'voting') {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) =>
                        VotingScreen(roomCode: widget.roomCode),
                  ),
                );
              }
            });
          }

          final participants = partSnap.docs;
          final proposals = proposalSnap.docs;
          final votes = voteSnap.docs;
          final tbDocs = tbSnap.docs;

          // Build tally for current round only
          final tally = _svc.tallyVotes(votes, currentRound);

          // Build sorted entries
          final entries = <_TallyEntry>[];
          for (final p in proposals) {
            final pData = p.data();
            entries.add(_TallyEntry(
              proposalId: p.id,
              authorName: (pData['authorName'] ?? 'Someone') as String,
              text: (pData['text'] ?? '') as String,
              voteCount: tally[p.id] ?? 0,
            ));
          }
          entries.sort((a, b) => b.voteCount.compareTo(a.voteCount));

          // Determine winners
          if (entries.isEmpty) {
            return const Center(child: Text('No proposals found.'));
          }

          final maxVotes = entries.first.voteCount;
          final winners =
              entries.where((e) => e.voteCount == maxVotes).toList();
          final isTie = winners.length > 1;

          // Tiebreaker state
          final tbChoices = <String, String>{};
          for (final doc in tbDocs) {
            tbChoices[doc.id] = (doc.data()['choice'] ?? '') as String;
          }

          if (tbChoices.containsKey(myUid) && !_hasChosenTieBreaker) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _hasChosenTieBreaker = true);
            });
          }

          final allChosen = tbChoices.length == participants.length &&
              participants.isNotEmpty;

          int revoteCount = 0;
          int randomCount = 0;
          for (final choice in tbChoices.values) {
            if (choice == 'revote') revoteCount++;
            if (choice == 'random') randomCount++;
          }

          // Determine majority (revote wins ties)
          final majorityIsRevote = allChosen && revoteCount >= randomCount;
          final majorityIsRandom = allChosen && randomCount > revoteCount;

          // If random winner is set in Firestore, start animation
          if (randomWinnerId != null &&
              isTie &&
              !_animationStarted &&
              winners.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _startShuffleAnimation(winners, randomWinnerId);
            });
          }

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

                // Leaderboard
                const Text(
                  'Leaderboard',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      final isWinner = entry.voteCount == maxVotes;

                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isWinner
                                ? Colors.amber.shade600
                                : Colors.grey.shade300,
                            width: isWinner ? 2.5 : 1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          color: isWinner
                              ? Colors.amber.shade50
                              : Colors.white,
                        ),
                        child: ListTile(
                          leading: isWinner
                              ? Icon(
                                  Icons.emoji_events,
                                  color: Colors.amber.shade700,
                                  size: 28,
                                )
                              : CircleAvatar(
                                  radius: 14,
                                  backgroundColor: Colors.grey.shade200,
                                  child: Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                          title: Text(
                            entry.authorName,
                            style: TextStyle(
                              fontWeight:
                                  isWinner ? FontWeight.bold : FontWeight.w500,
                            ),
                          ),
                          subtitle: Text(
                            entry.text,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isWinner
                                  ? Colors.amber.shade100
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              '${entry.voteCount}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: isWinner
                                    ? Colors.amber.shade900
                                    : Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),

                // --- Bottom section: single winner vs tie ---
                if (!isTie) ...[
                  // Single winner — host advances
                  if (isMeHost)
                    FilledButton(
                      onPressed: () async {
                        try {
                          await _svc.updateRoomPhase(
                            widget.roomCode,
                            'objection',
                          );
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                          }
                        }
                      },
                      child: const Text('Host: Continue to Objection'),
                    )
                  else
                    const FilledButton(
                      onPressed: null,
                      child: Text('Waiting for host to continue...'),
                    ),
                ] else if (randomWinnerId != null) ...[
                  // Random winner has been chosen — show animation or result
                  _buildRandomRevealSection(winners, randomWinnerId, isMeHost),
                ] else if (!allChosen) ...[
                  // Tie — members choose how to break it
                  _buildTieBreakerChoiceSection(
                    tbChoices,
                    participants.length,
                    revoteCount,
                    randomCount,
                  ),
                ] else if (majorityIsRevote) ...[
                  // Majority chose revote — host triggers it
                  _buildRevoteSection(winners, isMeHost),
                ] else if (majorityIsRandom) ...[
                  // Majority chose random — host triggers pick
                  _buildRandomTriggerSection(winners, isMeHost),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTieBreakerChoiceSection(
    Map<String, String> tbChoices,
    int totalParticipants,
    int revoteCount,
    int randomCount,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            border: Border.all(color: Colors.orange.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            "It's a tie! How should we break it?",
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
        ),
        const SizedBox(height: 12),
        if (!_hasChosenTieBreaker) ...[
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await _svc.submitTieBreakerChoice(
                      widget.roomCode,
                      'revote',
                    );
                    if (mounted) {
                      setState(() => _hasChosenTieBreaker = true);
                    }
                  },
                  icon: const Icon(Icons.how_to_vote),
                  label: const Text('Vote Again'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await _svc.submitTieBreakerChoice(
                      widget.roomCode,
                      'random',
                    );
                    if (mounted) {
                      setState(() => _hasChosenTieBreaker = true);
                    }
                  },
                  icon: const Icon(Icons.casino),
                  label: const Text('Pick Randomly'),
                ),
              ),
            ],
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              border: Border.all(color: Colors.green),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  'Your choice has been submitted!',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          '${tbChoices.length}/$totalParticipants have chosen',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildRevoteSection(List<_TallyEntry> winners, bool isMeHost) {
    final tiedNames = winners.map((e) => e.authorName).join(', ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            border: Border.all(color: Colors.blue.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'Majority voted to vote again!\nTied candidates: $tiedNames',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 12),
        if (isMeHost)
          FilledButton(
            onPressed: () async {
              try {
                final tiedIds = winners.map((e) => e.proposalId).toList();
                await _svc.startRevote(widget.roomCode, tiedIds);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Host: Start Revote'),
          )
        else
          const FilledButton(
            onPressed: null,
            child: Text('Waiting for host to start revote...'),
          ),
      ],
    );
  }

  Widget _buildRandomTriggerSection(
    List<_TallyEntry> winners,
    bool isMeHost,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.purple.shade50,
            border: Border.all(color: Colors.purple.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            'Majority voted for a random pick!',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 12),
        if (isMeHost)
          FilledButton(
            onPressed: () async {
              final rand = Random.secure();
              final winner = winners[rand.nextInt(winners.length)];
              try {
                await _svc.setRandomWinner(
                  widget.roomCode,
                  winner.proposalId,
                );
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Host: Pick a Random Winner!'),
          )
        else
          const FilledButton(
            onPressed: null,
            child: Text('Waiting for host to pick...'),
          ),
      ],
    );
  }

  Widget _buildRandomRevealSection(
    List<_TallyEntry> winners,
    String winnerId,
    bool isMeHost,
  ) {
    if (!_animationDone) {
      // Animation in progress — show cycling name
      final displayName = _tiedEntries.isNotEmpty
          ? _tiedEntries[_displayedIndex].authorName
          : '...';
      final displayText = _tiedEntries.isNotEmpty
          ? _tiedEntries[_displayedIndex].text
          : '';

      return Column(
        children: [
          const SizedBox(height: 8),
          const Text(
            'Picking a winner...',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 80),
            child: Card(
              key: ValueKey(_displayedIndex),
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.purple.shade300, width: 2),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      displayText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Animation done — show winner
    final winnerEntry = winners.firstWhere(
      (e) => e.proposalId == winnerId,
      orElse: () => winners.first,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.amber.shade600, width: 3),
          ),
          color: Colors.amber.shade50,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Icon(
                  Icons.emoji_events,
                  size: 48,
                  color: Colors.amber.shade700,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Winner!',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  winnerEntry.authorName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  winnerEntry.text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (isMeHost)
          FilledButton(
            onPressed: () async {
              try {
                await _svc.updateRoomPhase(widget.roomCode, 'objection');
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Host: Continue to Objection'),
          )
        else
          const FilledButton(
            onPressed: null,
            child: Text('Waiting for host to continue...'),
          ),
      ],
    );
  }
}

class _TallyEntry {
  final String proposalId;
  final String authorName;
  final String text;
  final int voteCount;

  _TallyEntry({
    required this.proposalId,
    required this.authorName,
    required this.text,
    required this.voteCount,
  });
}
