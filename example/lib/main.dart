import 'package:flip_page/flip_page.dart';
import 'package:flutter/material.dart';

void main() => runApp(const FlipPageExampleApp());

class FlipPageExampleApp extends StatelessWidget {
  const FlipPageExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'flip_page demo',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: const _DemoPage(),
    );
  }
}

class _DemoPage extends StatefulWidget {
  const _DemoPage();

  @override
  State<_DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<_DemoPage> {
  final FlipPageController _controller = FlipPageController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('flip_page demo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => _controller.previous(),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward),
            onPressed: () => _controller.next(),
          ),
        ],
      ),
      body: FlipPage(
        controller: _controller,
        onPageChanged: (i) => debugPrint('Page changed to $i'),
        pages: [
          _buildColorPage(Colors.red, '1', 'Drag from any corner to flip'),
          _buildInteractivePage(),
          _buildScrollablePage(),
          _buildColorPage(Colors.amber, '4', 'Content 4'),
          _buildColorPage(Colors.deepOrange, '5', 'Last page'),
        ],
      ),
    );
  }

  Widget _buildColorPage(Color color, String number, String subtitle) {
    return Container(
      color: color,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              number,
              style: const TextStyle(
                fontSize: 72,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 16, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInteractivePage() {
    return Container(
      color: Colors.teal,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Page 2 — Interactive',
              style: TextStyle(fontSize: 20, color: Colors.white),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Button tapped!')),
                );
              },
              child: const Text('Tap me'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScrollablePage() {
    return Container(
      color: Colors.indigo,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Page 3 — Scrollable list',
              style: TextStyle(fontSize: 20, color: Colors.white),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: 30,
              itemBuilder: (context, i) => ListTile(
                title: Text('Row $i', style: const TextStyle(color: Colors.white70)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
