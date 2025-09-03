import 'dart:io';

void main() async {
  final file = File('lib/screens/SellerPayoutsScreen.dart');
  String content = await file.readAsString();
  
  // Find the start of the build method
  final buildStart = content.indexOf('  @override\n  Widget build(BuildContext context) {');
  if (buildStart == -1) {
    print('Build method not found');
    return;
  }
  
  // Find the end by looking for the closing brace pattern
  int braceCount = 0;
  int buildEnd = buildStart;
  bool inMethod = false;
  
  for (int i = buildStart; i < content.length; i++) {
    if (content[i] == '{') {
      if (!inMethod) {
        inMethod = true;
      }
      braceCount++;
    } else if (content[i] == '}') {
      braceCount--;
      if (inMethod && braceCount == 0) {
        buildEnd = i;
        break;
      }
    }
  }
  
  if (buildEnd == buildStart) {
    print('Could not find end of build method');
    return;
  }
  
  // New build method content
  const newBuildMethod = '''  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.whisper,
      appBar: AppBar(
        title: const Text('Earnings & Payouts'),
        backgroundColor: AppTheme.deepTeal,
        foregroundColor: AppTheme.angel,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Navigate to simple home screen instead of just popping
            Navigator.of(context).pushNamedAndRemoveUntil(
              '/home',
              (route) => false,
            );
          },
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.angel,
          unselectedLabelColor: AppTheme.angel.withOpacity(0.7),
          indicatorColor: AppTheme.angel,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Overview'),
            Tab(icon: Icon(Icons.receipt_long), text: 'Receipts'),
            Tab(icon: Icon(Icons.history), text: 'History'),
            Tab(icon: Icon(Icons.settings), text: 'Settings'),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildOverviewTab(),
            _buildReceiptsTab(),
            _buildHistoryTab(),
            _buildSettingsTab(),
          ],
        ),
      ),
    );
  }''';
  
  // Replace the old build method
  final newContent = content.substring(0, buildStart) + 
                     newBuildMethod + 
                     content.substring(buildEnd + 1);
  
  // Write back to file
  await file.writeAsString(newContent);
  print('Build method updated successfully!');
  print('Build method start: $buildStart');
  print('Build method end: $buildEnd');
}
