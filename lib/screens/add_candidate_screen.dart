import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../components/glass_card.dart';
import '../components/gradient_button.dart';
import '../components/premium_field.dart';
import '../models/candidate.dart';
import '../services/candidate_service.dart';
import '../services/image_picker_service.dart';
import '../theme/app_theme.dart';
import '../utils/constants.dart';
import '../widgets/candidate_card.dart';
import '../widgets/photo_avatar.dart';

class AddCandidateScreen extends StatefulWidget {
  const AddCandidateScreen({super.key});

  @override
  State<AddCandidateScreen> createState() => _AddCandidateScreenState();
}

class _AddCandidateScreenState extends State<AddCandidateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _rollController = TextEditingController();
  final _uuid = const Uuid();
  final _imagePickerService = ImagePickerService();
  String? _selectedPosition;
  String? _selectedClass;
  String? _selectedSection;
  String? _photoPath;
  List<CandidateModel> _candidates = [];

  @override
  void initState() {
    super.initState();
    _loadCandidates();
  }

  void _loadCandidates() {
    setState(() => _candidates = CandidateService.getAll());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _rollController.dispose();
    super.dispose();
  }

  void _resetForm() {
    setState(() {
      _nameController.clear();
      _rollController.clear();
      _selectedPosition = null;
      _selectedClass = null;
      _selectedSection = null;
      _photoPath = null;
    });
  }

  Future<void> _saveCandidate() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPosition == null || _selectedClass == null || _selectedSection == null) {
      _showSnack('Please fill all fields');
      return;
    }
    final candidate = CandidateModel(
      id: _uuid.v4(),
      name: _nameController.text.trim(),
      position: _selectedPosition!,
      className: _selectedClass!,
      section: _selectedSection!,
      rollNumber: _rollController.text.trim(),
      photoPath: _photoPath,
    );
    await CandidateService.add(candidate);
    _resetForm();
    _loadCandidates();
    if (mounted) _showSnack('Candidate added successfully', isSuccess: true);
  }

  void _showSnack(String msg, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.inter(fontSize: 14)),
        backgroundColor: isSuccess ? AppTheme.secondaryGreen : AppTheme.errorRed,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Candidate')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          GlassCard(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        child: Stack(
                          children: [
                            PhotoAvatar(
                              photoPath: _photoPath,
                              initials: '?',
                              backgroundColor: const Color(0xFFF1F5F9),
                              size: 88,
                              borderRadius: 24,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [AppTheme.primaryBlue, AppTheme.secondaryPurple],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2.5),
                                ),
                                child: const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
                              ),
                            ),
                            if (_photoPath != null)
                              Positioned(
                                top: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: _removePhoto,
                                  child: Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: AppTheme.errorRed,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                    child: const Icon(Icons.close_rounded, size: 13, color: Colors.white),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Text(
                        _photoPath != null ? 'Tap to change' : 'Tap to add photo',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.primaryBlue),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  PremiumDropdown(
                    label: 'Position',
                    value: _selectedPosition,
                    items: AppConstants.positions,
                    onChanged: (v) => setState(() => _selectedPosition = v),
                  ),
                  const SizedBox(height: 14),
                  PremiumTextField(
                    controller: _nameController,
                    label: 'Student Name',
                    prefixIcon: Icons.person_outline,
                    validator: (v) => v == null || v.trim().isEmpty ? 'Enter name' : null,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: PremiumDropdown(
                          label: 'Class',
                          value: _selectedClass,
                          items: AppConstants.classes,
                          onChanged: (v) => setState(() => _selectedClass = v),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: PremiumDropdown(
                          label: 'Section',
                          value: _selectedSection,
                          items: AppConstants.sections,
                          onChanged: (v) => setState(() => _selectedSection = v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  PremiumTextField(
                    controller: _rollController,
                    label: 'Roll Number',
                    prefixIcon: Icons.badge_outlined,
                    validator: (v) => v == null || v.trim().isEmpty ? 'Enter roll number' : null,
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: GradientButton(
                          label: 'Save Candidate',
                          icon: Icons.save_rounded,
                          onPressed: _saveCandidate,
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: _resetForm,
                        icon: const Icon(Icons.refresh_rounded, size: 20),
                        label: const Text('Reset'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.textGrey,
                          side: const BorderSide(color: AppTheme.borderLight),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (_candidates.isNotEmpty) ...[
            SectionHeader(title: 'Registered Candidates', count: '${_candidates.length}'),
            const SizedBox(height: 16),
            ..._candidates.map((c) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: CandidateCard(
                candidate: c,
                onEdit: () => _showEditDialog(c),
                onDelete: () => _confirmDelete(c),
              ),
            )),
          ] else
            const EmptyState(
              icon: Icons.person_add_rounded,
              title: 'No candidates registered yet',
              subtitle: 'Add your first candidate using the form above',
            ),
        ],
      ),
    );
  }

  void _pickImage() {
    _imagePickerService.showImagePickerSheet(context, onImageSelected: (path) {
      setState(() => _photoPath = path);
    });
  }

  void _removePhoto() => setState(() => _photoPath = null);

  void _showEditDialog(CandidateModel candidate) {
    final nameCtrl = TextEditingController(text: candidate.name);
    final rollCtrl = TextEditingController(text: candidate.rollNumber);
    String? position = candidate.position;
    String? className = candidate.className;
    String? section = candidate.section;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Candidate'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PremiumTextField(controller: nameCtrl, label: 'Student Name', prefixIcon: Icons.person_outline),
              const SizedBox(height: 12),
              PremiumDropdown(
                label: 'Position', value: position, items: AppConstants.positions,
                onChanged: (v) => position = v,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: PremiumDropdown(
                      label: 'Class', value: className, items: AppConstants.classes,
                      onChanged: (v) => className = v,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: PremiumDropdown(
                      label: 'Section', value: section, items: AppConstants.sections,
                      onChanged: (v) => section = v,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              PremiumTextField(controller: rollCtrl, label: 'Roll Number', prefixIcon: Icons.badge_outlined),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          GradientButton(
            label: 'Save',
            onPressed: () async {
              await CandidateService.update(candidate.copyWith(
                name: nameCtrl.text.trim(), position: position, className: className,
                section: section, rollNumber: rollCtrl.text.trim(),
              ));
              if (ctx.mounted) Navigator.pop(ctx);
              _loadCandidates();
            },
            expanded: false,
          ),
        ],
      ),
    );
  }

  void _confirmDelete(CandidateModel candidate) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Candidate'),
        content: Text('Remove ${candidate.name} from the election?',
            style: GoogleFonts.inter(fontSize: 15, color: AppTheme.textGrey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          GradientButton(
            label: 'Delete',
            gradient: [AppTheme.errorRed, AppTheme.errorRed],
            onPressed: () async {
              await CandidateService.delete(candidate.id);
              if (ctx.mounted) Navigator.pop(ctx);
              _loadCandidates();
            },
            expanded: false,
          ),
        ],
      ),
    );
  }
}
