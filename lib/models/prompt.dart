/// A short "fill in the blank" prompt shown on a profile, Hinge-style —
/// gives people something to talk about beyond a list of sports.
class ProfilePrompt {
  final String question;
  final String answer;

  const ProfilePrompt({required this.question, required this.answer});

  factory ProfilePrompt.fromMap(Map<String, dynamic> map) =>
      ProfilePrompt(question: map['q'] as String, answer: map['a'] as String);

  Map<String, dynamic> toMap() => {'q': question, 'a': answer};
}

const kMaxPrompts = 2;
const kMaxPromptAnswerLength = 140;

const kPromptQuestions = [
  'Mein Lieblings-Trainingsort ist...',
  'Du findest mich garantiert beim...',
  'Nach dem Sport brauche ich unbedingt...',
  'Mein verrücktestes Sport-Erlebnis...',
  'Worauf ich beim Training am meisten achte...',
  'Das würde ich gerne mal ausprobieren...',
  'Mein Trick, wenn ich keine Lust habe...',
  'Perfektes Sport-Date für mich...',
];
