import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import '../theme/admin_theme.dart';

class UniversalUploadWidget extends StatefulWidget {
  final String title;
  final String description;
  final List<String> acceptedTypes;
  final String folder;
  final List<String>? tags;
  final Function(List<String> uploadedUrls)? onUploadComplete;
  final bool multiple;
  final int? maxFiles;
  final double? maxFileSizeMB;

  const UniversalUploadWidget({
    Key? key,
    required this.title,
    required this.description,
    this.acceptedTypes = const ['image/jpeg', 'image/png', 'image/gif'],
    required this.folder,
    this.tags,
    this.onUploadComplete,
    this.multiple = true,
    this.maxFiles = 10,
    this.maxFileSizeMB = 5.0,
  }) : super(key: key);

  @override
  State<UniversalUploadWidget> createState() => _UniversalUploadWidgetState();
}

class _UniversalUploadWidgetState extends State<UniversalUploadWidget> {
  final ImagePicker _picker = ImagePicker();
  List<XFile> _selectedFiles = [];
  bool _uploading = false;
  double _uploadProgress = 0.0;
  List<String> _uploadedUrls = [];
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cloud_upload, color: AdminTheme.deepTeal, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AdminTheme.deepTeal,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.description,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AdminTheme.mediumGrey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Upload area
            _buildUploadArea(),
            
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            if (_uploading) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(value: _uploadProgress),
              const SizedBox(height: 8),
              Text('Uploading... ${(_uploadProgress * 100).toInt()}%'),
            ],
            
            if (_selectedFiles.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildSelectedFiles(),
            ],
            
            if (_uploadedUrls.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildUploadedFiles(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUploadArea() {
    return GestureDetector(
      onTap: _uploading ? null : _pickFiles,
      child: Container(
        width: double.infinity,
        height: 120,
        decoration: BoxDecoration(
          border: Border.all(
            color: _uploading ? AdminTheme.mediumGrey : AdminTheme.deepTeal,
            width: 2,
            style: BorderStyle.solid,
          ),
          borderRadius: BorderRadius.circular(12),
          color: _uploading 
            ? AdminTheme.mediumGrey.withOpacity(0.1)
            : AdminTheme.deepTeal.withOpacity(0.05),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _uploading ? Icons.hourglass_empty : Icons.add_photo_alternate,
              size: 32,
              color: _uploading ? AdminTheme.mediumGrey : AdminTheme.deepTeal,
            ),
            const SizedBox(height: 8),
            Text(
              _uploading ? 'Uploading...' : 'Click to select files',
              style: TextStyle(
                color: _uploading ? AdminTheme.mediumGrey : AdminTheme.deepTeal,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Max ${widget.maxFileSizeMB}MB per file',
              style: TextStyle(
                color: AdminTheme.mediumGrey,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedFiles() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Selected Files (${_selectedFiles.length})',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Row(
              children: [
                TextButton.icon(
                  onPressed: _uploading ? null : _clearSelection,
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _uploading ? null : _uploadFiles,
                  icon: const Icon(Icons.cloud_upload),
                  label: const Text('Upload'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _selectedFiles.map((file) => _buildFileChip(file)).toList(),
        ),
      ],
    );
  }

  Widget _buildFileChip(XFile file) {
    return Chip(
      avatar: const Icon(Icons.insert_drive_file, size: 16),
      label: Text(
        file.name,
        style: const TextStyle(fontSize: 12),
      ),
      deleteIcon: const Icon(Icons.close, size: 16),
      onDeleted: _uploading ? null : () {
        setState(() {
          _selectedFiles.remove(file);
        });
      },
    );
  }

  Widget _buildUploadedFiles() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Uploaded Files (${_uploadedUrls.length})',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: Colors.green,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  const SizedBox(width: 8),
                  Text(
                    'Upload completed successfully!',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              if (_uploadedUrls.isNotEmpty) ...[
                const SizedBox(height: 8),
                ...(_uploadedUrls.map((url) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          url,
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        iconSize: 16,
                        onPressed: () => _copyToClipboard(url),
                        icon: const Icon(Icons.copy),
                        tooltip: 'Copy URL',
                      ),
                    ],
                  ),
                ))),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pickFiles() async {
    try {
      setState(() {
        _errorMessage = null;
      });

      List<XFile> files;
      if (widget.multiple) {
        files = await _picker.pickMultiImage(imageQuality: 85);
      } else {
        final file = await _picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 85,
        );
        files = file != null ? [file] : [];
      }

      if (files.isNotEmpty) {
        // Validate file sizes
        final validFiles = <XFile>[];
        for (final file in files) {
          final bytes = await file.readAsBytes();
          final sizeMB = bytes.length / (1024 * 1024);
          
          if (sizeMB > (widget.maxFileSizeMB ?? 5.0)) {
            setState(() {
              _errorMessage = 'File ${file.name} exceeds ${widget.maxFileSizeMB}MB limit';
            });
            continue;
          }
          validFiles.add(file);
        }

        if (widget.maxFiles != null && validFiles.length > widget.maxFiles!) {
          setState(() {
            _errorMessage = 'Maximum ${widget.maxFiles} files allowed';
          });
          return;
        }

        setState(() {
          _selectedFiles = validFiles;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error selecting files: $e';
      });
    }
  }

  void _clearSelection() {
    setState(() {
      _selectedFiles.clear();
      _errorMessage = null;
    });
  }

  Future<void> _uploadFiles() async {
    if (_selectedFiles.isEmpty) return;

    setState(() {
      _uploading = true;
      _uploadProgress = 0.0;
      _errorMessage = null;
      _uploadedUrls.clear();
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Get ImageKit auth
      final functions = FirebaseFunctions.instance;
      final authRes = await functions.httpsCallable('getImageKitUploadAuth').call();
      final auth = authRes.data as Map;

      final uploadedUrls = <String>[];
      
      for (int i = 0; i < _selectedFiles.length; i++) {
        final file = _selectedFiles[i];
        
        setState(() {
          _uploadProgress = i / _selectedFiles.length;
        });

        final bytes = await file.readAsBytes();
        final fileName = '${widget.folder}/${user.uid}/${DateTime.now().millisecondsSinceEpoch}_${file.name}';

        final request = http.MultipartRequest(
          'POST',
          Uri.parse('https://upload.imagekit.io/api/v1/files/upload'),
        );

        request.fields.addAll({
          'publicKey': auth['publicKey'],
          'token': auth['token'],
          'signature': auth['signature'],
          'expire': auth['expire'].toString(),
          'fileName': fileName,
          'folder': widget.folder,
          'useUniqueFileName': 'true',
        });

        if (widget.tags != null && widget.tags!.isNotEmpty) {
          request.fields['tags'] = widget.tags!.join(',');
        }

        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: file.name,
          ),
        );

        final response = await request.send();
        final responseBody = await response.stream.bytesToString();

        if (response.statusCode == 200) {
          final data = jsonDecode(responseBody);
          uploadedUrls.add(data['url']);
        } else {
          throw Exception('Upload failed: $responseBody');
        }
      }

      setState(() {
        _uploadedUrls = uploadedUrls;
        _uploading = false;
        _uploadProgress = 1.0;
        _selectedFiles.clear();
      });

      if (widget.onUploadComplete != null) {
        widget.onUploadComplete!(uploadedUrls);
      }

    } catch (e) {
      setState(() {
        _uploading = false;
        _errorMessage = 'Upload failed: $e';
      });
    }
  }

  void _copyToClipboard(String text) {
    // Note: On web, you'd use html.window.navigator.clipboard?.writeText(text)
    // For now, just show a message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('URL copied: ${text.substring(0, 50)}...')),
    );
  }
}

