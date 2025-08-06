import 'package:flutter/material.dart';

class ResponsiveDataTable extends StatefulWidget {
  final List<DataColumn> columns;
  final List<DataRow> rows;
  final bool sortAscending;
  final int? sortColumnIndex;
  final Function(int, bool)? onSort;
  final String? emptyMessage;
  final bool isLoading;

  const ResponsiveDataTable({
    Key? key,
    required this.columns,
    required this.rows,
    this.sortAscending = true,
    this.sortColumnIndex,
    this.onSort,
    this.emptyMessage,
    this.isLoading = false,
  }) : super(key: key);

  @override
  State<ResponsiveDataTable> createState() => _ResponsiveDataTableState();
}

class _ResponsiveDataTableState extends State<ResponsiveDataTable> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    
    if (widget.isLoading) {
      return _buildLoadingState(isMobile);
    }

    if (widget.rows.isEmpty) {
      return _buildEmptyState();
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: isMobile 
          ? _buildMobileLayout()
          : _buildDesktopLayout(),
    );
  }

  Widget _buildDesktopLayout() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: [
          // Header
          Container(
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            child: Row(
              children: widget.columns.asMap().entries.map((entry) {
                final index = entry.key;
                final column = entry.value;
                
                return Expanded(
                  flex: _getColumnFlex(index),
                  child: InkWell(
                    onTap: widget.onSort != null 
                        ? () => widget.onSort!(index, widget.sortColumnIndex == index ? !widget.sortAscending : true)
                        : null,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(child: column.label),
                          if (widget.onSort != null) ...[
                            const SizedBox(width: 4),
                            Icon(
                              widget.sortColumnIndex == index
                                  ? (widget.sortAscending ? Icons.arrow_upward : Icons.arrow_downward)
                                  : Icons.unfold_more,
                              size: 16,
                              color: widget.sortColumnIndex == index 
                                  ? Theme.of(context).primaryColor
                                  : Colors.grey[400],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          
          // Data rows
          Expanded(
            child: Scrollbar(
              controller: _scrollController,
              child: ListView.builder(
                controller: _scrollController,
                itemCount: widget.rows.length,
                itemBuilder: (context, index) {
                  final row = widget.rows[index];
                  return Container(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.grey[200]!,
                          width: 1,
                        ),
                      ),
                    ),
                    child: InkWell(
                      onTap: row.onSelectChanged != null 
                          ? () => row.onSelectChanged!(row.selected) 
                          : null,
                      child: Row(
                        children: row.cells.asMap().entries.map((entry) {
                          final cellIndex = entry.key;
                          final cell = entry.value;
                          
                          return Expanded(
                            flex: _getColumnFlex(cellIndex),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              child: cell.child,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: widget.rows.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final row = widget.rows[index];
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: row.onSelectChanged != null 
                ? () => row.onSelectChanged!(row.selected) 
                : null,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _buildMobileCardContent(row),
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildMobileCardContent(DataRow row) {
    List<Widget> content = [];
    
    for (int i = 0; i < row.cells.length && i < widget.columns.length; i++) {
      final column = widget.columns[i];
      final cell = row.cells[i];
      
      // Skip certain columns on mobile or show them differently
      if (_shouldSkipColumnOnMobile(i)) continue;
      
      content.add(
        Padding(
          padding: EdgeInsets.only(bottom: i == row.cells.length - 1 ? 0 : 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 100,
                child: Text(
                  _getColumnTitle(column.label),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: cell.child),
            ],
          ),
        ),
      );
    }
    
    return content;
  }

  Widget _buildLoadingState(bool isMobile) {
    if (isMobile) {
      return ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) => Card(
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    } else {
      return Container(
        height: 300,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
  }

  Widget _buildEmptyState() {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              widget.emptyMessage ?? 'No data available',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _getColumnFlex(int index) {
    // Customize column flex ratios based on content type
    if (index == 0) return 2; // First column (usually name/title)
    if (index == 1) return 2; // Second column
    return 1; // Other columns
  }

  bool _shouldSkipColumnOnMobile(int index) {
    // Skip certain columns on mobile for better readability
    // This can be customized based on specific needs
    return false;
  }

  String _getColumnTitle(Widget columnWidget) {
    // Extract text from column widget for mobile display
    if (columnWidget is Text) {
      return columnWidget.data ?? '';
    }
    return 'Column ${columnWidget.hashCode}';
  }
}

class ResponsiveDataTableHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget? leading;

  const ResponsiveDataTableHeader({
    Key? key,
    required this.title,
    this.subtitle,
    this.actions,
    this.leading,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: isMobile 
          ? _buildMobileHeader()
          : _buildDesktopHeader(),
    );
  }

  Widget _buildDesktopHeader() {
    return Row(
      children: [
        if (leading != null) ...[
          leading!,
          const SizedBox(width: 16),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ],
          ),
        ),
        if (actions != null) ...[
          const SizedBox(width: 16),
          Row(children: actions!),
        ],
      ],
    );
  }

  Widget _buildMobileHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
        if (actions != null) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: actions!,
          ),
        ],
      ],
    );
  }
} 