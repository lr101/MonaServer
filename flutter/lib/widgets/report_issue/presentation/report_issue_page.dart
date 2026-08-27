import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/widgets/buttons/presentation/custom_submit_button.dart';
import 'package:buff_lisa/widgets/custom_interaction/presentation/custom_error_snack_bar.dart';
import 'package:buff_lisa/widgets/custom_scaffold/presentation/custom_close_keyboard_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ReportIssuePage extends ConsumerStatefulWidget {

  final String? userId;
  final String? groupId;
  final String? pinId;
  final List<String> issueTypes;

  const ReportIssuePage({super.key, this.userId, this.groupId, this.pinId, required this.issueTypes});

  @override
  ConsumerState<ReportIssuePage> createState() => _ReportIssuePageState();

}

class _ReportIssuePageState extends ConsumerState<ReportIssuePage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _messageController = TextEditingController();
  late String? _selectedIssueType;
  bool sending = false;

  @override
  void initState() {
    _selectedIssueType = widget.issueTypes.first;
    super.initState();
  }


  String? _validateMessage(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your message';
    } else if (value.length > 1000) {
      return 'Message must be less than 1000 characters';
    }
    return null;
  }

  // Function to handle the report submission
  Future<void> _submitReport() async {
    if (_formKey.currentState!.validate() && !sending) {
      setState(() {
        sending = true;
      });
      final result = await ref.read(authServiceProvider.notifier).report("userId: ${widget.userId}, groupId: ${widget.groupId}, pinId: ${widget.pinId}, issueType: $_selectedIssueType", _messageController.text);
      if (result != null) {
        CustomErrorSnackBar.message(message: result);
      } else if (mounted) {
        Navigator.of(context).pop();
      }
      setState(() {
        sending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomCloseKeyboardScaffold(
      appBar: AppBar(
        title: const Text('Report Issue'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select Issue Type'),
                const SizedBox(height: 8.0),
                DropdownButtonFormField<String>(
                  initialValue: _selectedIssueType,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  items: widget.issueTypes.map((String type) {
                    return DropdownMenuItem<String>(
                      value: type,
                      child: Text(type),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedIssueType = newValue;
                    });
                  },
                ),
                const SizedBox(height: 16.0),

                // Message TextField
                const Text('Write your message'),
                const SizedBox(height: 8.0),
                TextFormField(
                  controller: _messageController,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    hintText: 'Describe your issue or suggestion...',
                    border: OutlineInputBorder(),
                  ),
                  validator: _validateMessage,
                ),
                const SizedBox(height: 24.0),

                // Submit Button
                SubmitButton(onPressed: _submitReport, icon: Icons.send),

              ],
            ),
          ),
        ),
      ),
    );
  }
}
