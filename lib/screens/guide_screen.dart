import 'package:flutter/material.dart';

class GuideScreen extends StatefulWidget {
  const GuideScreen({super.key});

  @override
  State<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends State<GuideScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final int _totalPages = 11;

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goHome() => Navigator.pop(context);

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (i) => setState(() => _currentPage = i),
        children: [
          _GuidePage(
            onNext: _nextPage,
            onPrev: _prevPage,
            onHome: _goHome,
            isFirst: true,
            isLast: false,
            child: const _Page1Content(),
          ),
          _GuidePage(
            onNext: _nextPage,
            onPrev: _prevPage,
            onHome: _goHome,
            isFirst: false,
            isLast: false,
            child: const _Page2Content(),
          ),
          _GuidePage(
            onNext: _nextPage,
            onPrev: _prevPage,
            onHome: _goHome,
            isFirst: false,
            isLast: false,
            child: const _Page3Content(),
          ),
          _GuidePage(
            onNext: _nextPage,
            onPrev: _prevPage,
            onHome: _goHome,
            isFirst: false,
            isLast: false,
            child: const _Page4Content(),
          ),
          _GuidePage(
            onNext: _nextPage,
            onPrev: _prevPage,
            onHome: _goHome,
            isFirst: false,
            isLast: false,
            child: const _Page5Content(),
          ),
          _GuidePage(
            onNext: _nextPage,
            onPrev: _prevPage,
            onHome: _goHome,
            isFirst: false,
            isLast: false,
            child: const _Page6Content(),
          ),
          _GuidePage(
            onNext: _nextPage,
            onPrev: _prevPage,
            onHome: _goHome,
            isFirst: false,
            isLast: false,
            child: const _Page7Content(),
          ),
          _GuidePage(
            onNext: _nextPage,
            onPrev: _prevPage,
            onHome: _goHome,
            isFirst: false,
            isLast: false,
            child: const _Page8Content(),
          ),
          _GuidePage(
            onNext: _nextPage,
            onPrev: _prevPage,
            onHome: _goHome,
            isFirst: false,
            isLast: false,
            child: const _Page9Content(),
          ),
          _GuidePage(
            onNext: _nextPage,
            onPrev: _prevPage,
            onHome: _goHome,
            isFirst: false,
            isLast: false,
            child: const _Page10Content(),
          ),
          _GuidePage(
            onNext: _nextPage,
            onPrev: _prevPage,
            onHome: _goHome,
            isFirst: false,
            isLast: true,
            child: const _Page11Content(),
          ),
        ],
      ),
    );
  }
}

class _GuidePage extends StatelessWidget {
  final VoidCallback onNext;
  final VoidCallback onPrev;
  final VoidCallback onHome;
  final bool isFirst;
  final bool isLast;
  final Widget child;

  const _GuidePage({
    required this.onNext,
    required this.onPrev,
    required this.onHome,
    required this.isFirst,
    required this.isLast,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFCFE87A),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    onPressed: onHome,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      side: const BorderSide(color: Colors.black, width: 1),
                    ),
                    child: const Text('Home page'),
                  ),
                  if (!isFirst)
                    GestureDetector(
                      onTap: onPrev,
                      child: SizedBox(
                        width: 90,
                        height: 44,
                        child: Stack(
                          children: [
                            ClipPath(
                              clipper: _ArrowBackClipper(),
                              child: Container(color: Colors.white),
                            ),
                            CustomPaint(
                              painter: _ArrowBackBorderPainter(),
                              child: const SizedBox(width: 90, height: 44),
                            ),
                            const Positioned.fill(
                              child: Center(
                                child: Text('Back', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (!isLast)
                    GestureDetector(
                      onTap: onNext,
                      child: SizedBox(
                        width: 90,
                        height: 44,
                        child: Stack(
                          children: [
                            ClipPath(
                              clipper: _ArrowClipper(),
                              child: Container(color: Colors.white),
                            ),
                            CustomPaint(
                              painter: _ArrowBorderPainter(),
                              child: const SizedBox(width: 90, height: 44),
                            ),
                            const Positioned.fill(
                              child: Center(
                                child: Text('Next', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class _ArrowBackClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    final arrowWidth = size.width * 0.25;
    path.moveTo(arrowWidth, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height);
    path.lineTo(arrowWidth, size.height);
    path.lineTo(0, size.height / 2);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(_ArrowBackClipper _) => false;
}

class _ArrowBackBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final arrowWidth = size.width * 0.25;
    final path = Path()
      ..moveTo(arrowWidth, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(arrowWidth, size.height)
      ..lineTo(0, size.height / 2)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ArrowBackBorderPainter _) => false;
}

class _ArrowBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final arrowWidth = size.width * 0.25;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width - arrowWidth, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(size.width - arrowWidth, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ArrowBorderPainter _) => false;
}

class _ArrowClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    final arrowWidth = size.width * 0.25;
    path.moveTo(0, 0);
    path.lineTo(size.width - arrowWidth, 0);
    path.lineTo(size.width, size.height / 2);
    path.lineTo(size.width - arrowWidth, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(_ArrowClipper _) => false;
}

class _Page11Content extends StatelessWidget {
  const _Page11Content();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.black, width: 2),
            ),
            child: RichText(
              textAlign: TextAlign.center,
              text: const TextSpan(
                style: TextStyle(fontSize: 22, color: Colors.black),
                children: [
                  TextSpan(text: 'You will now see that the green play button has turned red with the "'),
                  TextSpan(text: 'Stop', style: TextStyle(color: Colors.red)),
                  TextSpan(text: '" text, and a new green "'),
                  TextSpan(text: 'Active', style: TextStyle(color: Colors.green)),
                  TextSpan(text: '". You can press the green button to view the live stream but you do not need to.'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Image.asset('assets/guide_11.jpeg', fit: BoxFit.contain),
          ),
        ],
      ),
    );
  }
}

class _Page10Content extends StatelessWidget {
  const _Page10Content();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.black, width: 2),
            ),
            child: const Text(
              'You can navigate back to the home page at any time by pressing the green "Home page" next to the red arrow.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, color: Colors.black),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Image.asset('assets/guide_10.png', fit: BoxFit.contain),
          ),
        ],
      ),
    );
  }
}

class _Page9Content extends StatelessWidget {
  const _Page9Content();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.black, width: 2),
            ),
            child: RichText(
              textAlign: TextAlign.center,
              text: const TextSpan(
                style: TextStyle(fontSize: 22, color: Colors.black),
                children: [
                  TextSpan(text: 'Enter the username and password from your '),
                  TextSpan(text: 'CAMERA APP', style: TextStyle(color: Colors.red)),
                  TextSpan(text: ' that you have installed when purchased the camera. If you do not remember them, open your '),
                  TextSpan(text: 'CAMERA APP', style: TextStyle(color: Colors.red)),
                  TextSpan(text: ' and look there. You only have to do this step once.'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Image.asset('assets/guide_9.jpeg', fit: BoxFit.contain),
          ),
        ],
      ),
    );
  }
}

class _Page8Content extends StatelessWidget {
  const _Page8Content();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.black, width: 2),
            ),
            child: const Text(
              'Otherwise, you will see a list of the cameras found. In this version you can only choose one camera — pick the one you want.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, color: Colors.black),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Image.asset('assets/guide_8.jpeg', fit: BoxFit.contain),
          ),
        ],
      ),
    );
  }
}

class _Page7Content extends StatelessWidget {
  const _Page7Content();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.black, width: 2),
            ),
            child: const Text(
              'If the WiFi is connected but the camera is not, you will see this message.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, color: Colors.black),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Image.asset('assets/guide_7.jpeg', fit: BoxFit.contain),
          ),
        ],
      ),
    );
  }
}

class _Page6Content extends StatelessWidget {
  const _Page6Content();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.black, width: 2),
            ),
            child: const Text(
              'If you get this message, it means your WiFi is not connected.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, color: Colors.black),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Image.asset('assets/guide_6.jpeg', fit: BoxFit.contain),
          ),
        ],
      ),
    );
  }
}

class _Page5Content extends StatelessWidget {
  const _Page5Content();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.black, width: 2),
            ),
            child: RichText(
              textAlign: TextAlign.center,
              text: const TextSpan(
                style: TextStyle(fontSize: 22, color: Colors.black),
                children: [
                  TextSpan(text: 'To get started, '),
                  TextSpan(text: 'FIRST MAKE SURE YOUR DEVICE IS CONNECTED TO WIFI,', style: TextStyle(color: Colors.red)),
                  TextSpan(text: ' then press the green Start button shown with the arrow.'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Image.asset('assets/guide_5.png', fit: BoxFit.contain),
          ),
        ],
      ),
    );
  }
}

class _Page4Content extends StatelessWidget {
  const _Page4Content();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.black, width: 2),
            ),
            child: const Text(
              'The video will run, and after a few seconds you should see the snake detections.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, color: Colors.black),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Row(
              children: [
                Expanded(child: Image.asset('assets/guide_4a.jpeg', fit: BoxFit.contain)),
                const SizedBox(width: 8),
                Expanded(child: Image.asset('assets/guide_4b.jpeg', fit: BoxFit.contain)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Page3Content extends StatelessWidget {
  const _Page3Content();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.black, width: 2),
            ),
            child: const Text(
              'Now you can simply choose a video from your device.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, color: Colors.black),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Image.asset('assets/guide_3.jpeg', fit: BoxFit.contain),
          ),
        ],
      ),
    );
  }
}

class _Page1Content extends StatelessWidget {
  const _Page1Content();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          const Text(
            'Hi, welcome to the Snakes Detector app guide.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 26, color: Colors.black, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.black, width: 2),
            ),
            child: RichText(
              textAlign: TextAlign.center,
              text: const TextSpan(
                style: TextStyle(fontSize: 22, color: Colors.black),
                children: [
                  TextSpan(text: 'This app works with any '),
                  TextSpan(text: 'ONVIF', style: TextStyle(color: Colors.red, fontSize: 26)),
                  TextSpan(text: '-compatible IP camera, including popular brands such as '),
                  TextSpan(text: 'Tapo', style: TextStyle(color: Colors.red, fontSize: 26)),
                  TextSpan(text: ', '),
                  TextSpan(text: 'Hikvision', style: TextStyle(color: Colors.red, fontSize: 26)),
                  TextSpan(text: ', '),
                  TextSpan(text: 'Dahua', style: TextStyle(color: Colors.red, fontSize: 26)),
                  TextSpan(text: ', '),
                  TextSpan(text: 'Reolink', style: TextStyle(color: Colors.red, fontSize: 26)),
                  TextSpan(text: ', and '),
                  TextSpan(text: 'Amcrest', style: TextStyle(color: Colors.red, fontSize: 26)),
                  TextSpan(text: '.'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'For any questions, please feel free to contact us at:',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, color: Colors.black),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.black, width: 2),
            ),
            child: const Text(
              'kbengalil@gmail.com',
              style: TextStyle(fontSize: 26, color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}

class _Page2Content extends StatelessWidget {
  const _Page2Content();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.black, width: 2),
            ),
            child: const Text(
              'You can test your app with a video of a snake. If you do not have one, simply create one using a tool like Gemini video generator. Press the "Test my app" button marked with the arrow.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, color: Colors.black),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Image.asset('assets/guide_2.png', fit: BoxFit.contain),
          ),
        ],
      ),
    );
  }
}
