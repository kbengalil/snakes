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
                      child: ClipPath(
                        clipper: _ArrowBackClipper(),
                        child: Container(
                          width: 90,
                          height: 44,
                          color: Colors.white,
                          child: const Center(
                            child: Text('Back', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                    ),
                  if (!isLast)
                    GestureDetector(
                      onTap: onNext,
                      child: ClipPath(
                        clipper: _ArrowClipper(),
                        child: Container(
                          width: 90,
                          height: 44,
                          color: Colors.white,
                          child: const Center(
                            child: Text('Next', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
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
            child: const Text(
              'In the home screen you will now see that the green play button has turned red with the "Stop" text, and the green box "Live — monitoring active".',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, color: Colors.black),
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
            child: const Text(
              'You will be asked to enter a username and password. These are the username and password from your camera app that you received when you purchased the camera. If you do not remember them, open your camera app and look there.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, color: Colors.black),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Row(
              children: [
                Expanded(child: Image.asset('assets/guide_9a.jpeg', fit: BoxFit.contain)),
                const SizedBox(width: 8),
                Expanded(child: Image.asset('assets/guide_9b.jpeg', fit: BoxFit.contain)),
              ],
            ),
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
            child: const Text(
              'To get started, first make sure your device is connected to WiFi, then press the green Start button shown with the red arrow.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, color: Colors.black),
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
        children: const [
          SizedBox(height: 40),
          Text(
            'Hi, welcome to the Snakes Detector app.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 26, color: Colors.black, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 24),
          Text(
            'This app works with any ONVIF-compatible IP camera, including popular brands such as Tapo, Hikvision, Dahua, Reolink, and Amcrest.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, color: Colors.black),
          ),
          SizedBox(height: 24),
          Text(
            'For any questions, please feel free to contact us at kbengalil@gmail.com. Now let\'s get started!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, color: Colors.black),
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
              'First, you are welcome to test this app with a video of a snake. If you do not have one, you can create one using a tool like Gemini video generator. Just press the "Test my app" button marked with the green arrow.',
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
