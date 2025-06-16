// pages/upload_prescription.dart
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'ProductModel.dart';

class UploadPrescriptionPage extends StatefulWidget {
  final Product product;

  const UploadPrescriptionPage({
    Key? key,
    required this.product,
  }) : super(key: key);

  @override
  State<UploadPrescriptionPage> createState() => _UploadPrescriptionPageState();
}

class _UploadPrescriptionPageState extends State<UploadPrescriptionPage> {
  File? _image;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    final XFile? pickedFile =
        await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Upload Prescription'),
        backgroundColor: Colors.green[700],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Prescription Required',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'This product requires a prescription. Please upload a clear image of your prescription.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 24),
            Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _image == null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.upload_file,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                          SizedBox(height: 8),
                          Text(
                            'No prescription uploaded',
                            style: TextStyle(
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                  : Image.file(
                      _image!,
                      fit: BoxFit.cover,
                    ),
            ),
            SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _pickImage,
              icon: Icon(Icons.upload_file),
              label: Text('Upload Prescription'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                minimumSize: Size(double.infinity, 50),
              ),
            ),
            SizedBox(height: 16),
            if (_image != null)
              ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Prescription submitted successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  minimumSize: Size(double.infinity, 50),
                ),
                child: Text('Submit Prescription'),
              ),
          ],
        ),
      ),
    );
  }
}
