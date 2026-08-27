import 'dart:typed_data';

import 'package:buff_lisa/data/entity/group_entity.dart';
import 'package:buff_lisa/data/service/image_service.dart';
import 'package:buff_lisa/widgets/buttons/presentation/custom_submit_button.dart';
import 'package:buff_lisa/widgets/group_edit_template/service/group_create_service.dart';
import 'package:buff_lisa/widgets/round_image/presentation/round_image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mutex/mutex.dart';

class GroupEditTemplate extends ConsumerStatefulWidget {
  const GroupEditTemplate(
      {super.key,
      required this.onSubmit,
      this.rowItems,
      this.groupDto,
      required this.title,});

  final Future<void> Function(
    String name,
    String description,
    String? link,
    Uint8List profileImage,
    int visibility,
  ) onSubmit;

  final List<Widget>? rowItems;
  final GroupEntity? groupDto;
  final String title;

  @override
  ConsumerState<GroupEditTemplate> createState() => _GroupEditTemplate();
}

class _GroupEditTemplate extends ConsumerState<GroupEditTemplate> {
  final _textEditControllerName = TextEditingController();
  final _textEditControllerDescription = TextEditingController();
  final _textEditControllerLink = TextEditingController();
  final _isLoading = ValueNotifier(false);
  final _mutex = Mutex();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    if (widget.groupDto != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final image = ref
            .watch(groupProfilePictureByIdProvider(widget.groupDto!.groupId))
            .value; // should exists because editing can only be done to a user group but better solution needed in the future
        ref
            .read(groupCreateServiceProvider.notifier)
            .init(widget.groupDto!, image);
        _textEditControllerName.text = widget.groupDto!.name;
        _textEditControllerDescription.text = widget.groupDto!.description!;
        _textEditControllerLink.text = widget.groupDto!.link ?? "";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final group = ref.watch(groupCreateServiceProvider);
    final groupNotifier = ref.watch(groupCreateServiceProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    SizedBox(
                      width: 90,
                      child: RoundImagePicker(
                        size: 40,
                        imageUpload: (image) {
                          groupNotifier.updateProfileImage(image);
                        },
                        imageCallback: AsyncData(
                          ref.watch(createGroupProfileImageProvider),
                        ),
                      ),
                    ),
                    const SizedBox(
                      width: 10,
                    ),
                    SizedBox(
                      width: MediaQuery.of(context).size.width - 120,
                      child: TextFormField(
                        controller: _textEditControllerName,
                        validator: (value) =>
                            value!.isEmpty ? "Please enter a group name" : null,
                        textAlign: TextAlign.left,
                        decoration: const InputDecoration(
                          hintText: "Type your group name",
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(
                height: 5,
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.85,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Description:",
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                      TextFormField(
                        validator: (value) => value!.isEmpty
                            ? "Please enter a group description"
                            : null,
                        controller: _textEditControllerDescription,
                        keyboardType: TextInputType.multiline,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.normal,
                        ),
                        decoration: const InputDecoration(
                          hintText: "Type your group description",
                        ),
                        maxLines: null,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(
                height: 5,
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.85,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Url/Link:",
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                      TextFormField(
                        validator: (value) => value == null ||
                                value.isEmpty ||
                                Uri.parse(value).isAbsolute
                            ? null
                            : "Invalid link",
                        controller: _textEditControllerLink,
                        keyboardType: TextInputType.url,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.normal,
                        ),
                        decoration: const InputDecoration(
                          hintText: "Type your link (optional)",
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(
                height: 5,
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.85,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Group privacy:",
                        style: TextStyle(
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          const Icon(Icons.lock_open),
                          const SizedBox(
                            width: 5,
                          ),
                          Switch(
                            value: group.visibility == 1,
                            onChanged: (value) =>
                                groupNotifier.updateVisibility(!value ? 0 : 1),
                          ),
                          const SizedBox(
                            width: 5,
                          ),
                          const Icon(Icons.lock),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(
                height: 5,
              ),
              ...widget.rowItems ?? [],
            ],
          ),
        ),
      ),
      floatingActionButton: SubmitButton(
        onPressed: () async {
          final group = ref.watch(groupCreateServiceProvider);
          if (_formKey.currentState!.validate() &&
              group.profileImage != null &&
              !_mutex.isLocked) {
            try {
              _mutex.acquire();
              _isLoading.value = true;
              await widget.onSubmit(
                _textEditControllerName.text,
                _textEditControllerDescription.text,
                _textEditControllerLink.text.isEmpty
                    ? null
                    : _textEditControllerLink.text,
                group.profileImage!,
                group.visibility,
              );
            } finally {
              _isLoading.value = false;
              _mutex.release();
            }
          }
        },
      ),
    );
  }
}
