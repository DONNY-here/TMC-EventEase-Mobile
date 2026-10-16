part of 'main.dart';

class ECertificateScreen extends StatelessWidget {
  final String studentName;
  final String course;
  final String yearLevel;
  final String eventTitle;
  final String eventDate;

  const ECertificateScreen({
    super.key,
    required this.studentName,
    required this.course,
    required this.yearLevel,
    required this.eventTitle,
    required this.eventDate,
  });

  String get formattedDate => eventDate;

  @override
  Widget build(BuildContext context) {
    const maroon = Color(0xFF800020);
    const gold = Color(0xFFD4AF37);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My E-Certificate'),
        backgroundColor: maroon,
        foregroundColor: Colors.white,
      ),
      backgroundColor: const Color(0xFFF5F5F5),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Certificate of Participation',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your certificate for completing the event.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: gold,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 35,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFCF2),
                  border: Border.all(color: maroon, width: 2),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.workspace_premium, size: 65, color: gold),
                    const SizedBox(height: 12),
                    const Text(
                      'TRINIDAD MUNICIPAL COLLEGE',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: maroon,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'TMC EVENTEASE',
                      style: TextStyle(fontSize: 12, letterSpacing: 2),
                    ),
                    const SizedBox(height: 26),
                    const Text(
                      'CERTIFICATE OF PARTICIPATION',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                        color: maroon,
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'This certificate is proudly presented to',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      studentName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(color: gold, thickness: 2, height: 32),
                    const Text(
                      'For successfully participating in',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      eventTitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                        color: maroon,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text('Held on $formattedDate', textAlign: TextAlign.center),
                    const SizedBox(height: 35),
                    const Divider(color: gold),
                    const Text(
                      'Issued through TMC EventEase',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
