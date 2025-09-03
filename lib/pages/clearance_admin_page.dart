// pages/clearance_admin_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/clearance_sale_provider.dart';

class ClearanceAdminPage extends StatefulWidget {
  const ClearanceAdminPage({Key? key}) : super(key: key);

  @override
  State<ClearanceAdminPage> createState() => _ClearanceAdminPageState();
}

class _ClearanceAdminPageState extends State<ClearanceAdminPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _discountController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clearance Sale Admin'),
        backgroundColor: Colors.red[700],
        foregroundColor: Colors.white,
      ),
      body: Consumer<ClearanceSaleProvider>(
        builder: (context, clearanceProvider, child) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Current Status
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current Status',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              clearanceProvider.isActive
                                  ? Icons.check_circle
                                  : Icons.cancel,
                              color: clearanceProvider.isActive
                                  ? Colors.green
                                  : Colors.red,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              clearanceProvider.isActive
                                  ? 'Clearance Sale Active'
                                  : 'No Active Sale',
                              style: TextStyle(
                                color: clearanceProvider.isActive
                                    ? Colors.green
                                    : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        if (clearanceProvider.isActive) ...[
                          const SizedBox(height: 8),
                          Text('Sale Name: ${clearanceProvider.saleName}'),
                          Text(
                              'Discount: ${clearanceProvider.discountPercentage.toInt()}%'),
                          Text(
                              'Description: ${clearanceProvider.saleDescription}'),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Admin Controls
                Text(
                  'Admin Controls',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),

                if (!clearanceProvider.isActive) ...[
                  // Activate Sale Form
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Activate Clearance Sale',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Sale Name',
                              hintText: 'e.g., Mega Clearance Sale',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _descriptionController,
                            decoration: const InputDecoration(
                              labelText: 'Description',
                              hintText: 'e.g., Amazing deals on all products',
                              border: OutlineInputBorder(),
                            ),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _discountController,
                            decoration: const InputDecoration(
                              labelText: 'Discount Percentage',
                              hintText: 'e.g., 50',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: clearanceProvider.isLoading
                                  ? null
                                  : () async {
                                      final name = _nameController.text.trim();
                                      final description =
                                          _descriptionController.text.trim();
                                      final discountText =
                                          _discountController.text.trim();

                                      if (name.isEmpty ||
                                          description.isEmpty ||
                                          discountText.isEmpty) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                                'Please fill in all fields'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                        return;
                                      }

                                      final discount =
                                          double.tryParse(discountText);
                                      if (discount == null ||
                                          discount <= 0 ||
                                          discount > 100) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                                'Please enter a valid discount percentage (1-100)'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                        return;
                                      }

                                      try {
                                        await clearanceProvider
                                            .activateClearanceSale(
                                          name: name,
                                          description: description,
                                          discountPercentage: discount,
                                        );

                                        _nameController.clear();
                                        _descriptionController.clear();
                                        _discountController.clear();

                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                                'Clearance sale activated successfully!'),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                      } catch (e) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text('Error: $e'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red[700],
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: clearanceProvider.isLoading
                                  ? const CircularProgressIndicator(
                                      color: Colors.white)
                                  : const Text('Activate Clearance Sale'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  // Deactivate Sale
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Deactivate Clearance Sale',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: clearanceProvider.isLoading
                                  ? null
                                  : () async {
                                      try {
                                        await clearanceProvider
                                            .deactivateClearanceSale();

                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                                'Clearance sale deactivated successfully!'),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                      } catch (e) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text('Error: $e'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange[700],
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: clearanceProvider.isLoading
                                  ? const CircularProgressIndicator(
                                      color: Colors.white)
                                  : const Text('Deactivate Clearance Sale'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }
}
