library edit_profile_studio;

import 'package:flutter/material.dart';
import 'package:telly_app/core/theme/telly_colors.dart';
import 'package:telly_app/core/theme/telly_typography.dart';
import 'package:telly_app/core/widgets/telly_neon_badge.dart';
import 'package:telly_app/core/widgets/telly_primary_button.dart';

/// Screen model for user profile state.
class ProfileStudioData {
  final String displayName;
  final String handle;
  final String bio;
  final String favoriteCreator;
  final List<String> top3Showcase;
  final String visibilityMode; // 'PUBLIC', 'FRIENDS_ONLY', 'GHOST'
  final bool showGraveyard;
  final bool allowCoWatch;
  final bool autoBlurSpoilers;
  final String? avatarUrl;

  const ProfileStudioData({
    required this.displayName,
    required this.handle,
    required this.bio,
    required this.favoriteCreator,
    required this.top3Showcase,
    this.visibilityMode = 'PUBLIC',
    this.showGraveyard = true,
    this.allowCoWatch = true,
    this.autoBlurSpoilers = true,
    this.avatarUrl,
  });

  ProfileStudioData copyWith({
    String? displayName,
    String? handle,
    String? bio,
    String? favoriteCreator,
    List<String>? top3Showcase,
    String? visibilityMode,
    bool? showGraveyard,
    bool? allowCoWatch,
    bool? autoBlurSpoilers,
    String? avatarUrl,
  }) {
    return ProfileStudioData(
      displayName: displayName ?? this.displayName,
      handle: handle ?? this.handle,
      bio: bio ?? this.bio,
      favoriteCreator: favoriteCreator ?? this.favoriteCreator,
      top3Showcase: top3Showcase ?? this.top3Showcase,
      visibilityMode: visibilityMode ?? this.visibilityMode,
      showGraveyard: showGraveyard ?? this.showGraveyard,
      allowCoWatch: allowCoWatch ?? this.allowCoWatch,
      autoBlurSpoilers: autoBlurSpoilers ?? this.autoBlurSpoilers,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }
}

/// SCR-08: Edit Profile Studio, Avatar Cropper & Top 3 Showcase.
/// Conforms to `FE-507` and `docs/adjacent_systems/02_PROFILE_MANAGEMENT_AND_CUSTOMIZATION.md` §1–§4.
class EditProfileStudioScreen extends StatefulWidget {
  final ProfileStudioData? initialData;

  const EditProfileStudioScreen({
    super.key,
    this.initialData,
  });

  @override
  State<EditProfileStudioScreen> createState() => _EditProfileStudioScreenState();
}

class _EditProfileStudioScreenState extends State<EditProfileStudioScreen> {
  late final TextEditingController _displayNameController;
  late final TextEditingController _handleController;
  late final TextEditingController _bioController;
  late final TextEditingController _creatorController;

  late List<String> _top3;
  late String _visibilityMode;
  late bool _showGraveyard;
  late bool _allowCoWatch;
  late bool _autoBlurSpoilers;
  String? _selectedAvatarIcon;

  final List<String> _iconicAvatars = [
    '☕ Royco Mug',
    '🧇 Lumon Waffle',
    '🍳 Chef Apron',
    '🎩 Heisenberg',
    '🗡️ Valyrian Steel',
  ];

  @override
  void initState() {
    super.initState();
    final data = widget.initialData ??
        const ProfileStudioData(
          displayName: 'Jordan Miller',
          handle: 'jordan',
          bio: 'HBO loyalist. Severance truther. Don\'t talk to me about the Game of Thrones finale.',
          favoriteCreator: 'Jesse Armstrong (Succession)',
          top3Showcase: ['Succession (HBO)', 'Severance (Apple TV+)', 'The Bear (FX)'],
          visibilityMode: 'PUBLIC',
        );

    _displayNameController = TextEditingController(text: data.displayName);
    _handleController = TextEditingController(text: data.handle);
    _bioController = TextEditingController(text: data.bio);
    _creatorController = TextEditingController(text: data.favoriteCreator);
    _top3 = List.from(data.top3Showcase);
    _visibilityMode = data.visibilityMode;
    _showGraveyard = data.showGraveyard;
    _allowCoWatch = data.allowCoWatch;
    _autoBlurSpoilers = data.autoBlurSpoilers;
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _handleController.dispose();
    _bioController.dispose();
    _creatorController.dispose();
    super.dispose();
  }

  void _saveProfile() {
    final updated = ProfileStudioData(
      displayName: _displayNameController.text.trim(),
      handle: _handleController.text.trim().replaceAll('@', ''),
      bio: _bioController.text.trim(),
      favoriteCreator: _creatorController.text.trim(),
      top3Showcase: _top3,
      visibilityMode: _visibilityMode,
      showGraveyard: _showGraveyard,
      allowCoWatch: _allowCoWatch,
      autoBlurSpoilers: _autoBlurSpoilers,
      avatarUrl: _selectedAvatarIcon,
    );

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Profile saved successfully!'),
          backgroundColor: TellyColors.backgroundCard,
        ),
      );

    Navigator.of(context).pop(updated);
  }

  void _showAvatarPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: TellyColors.backgroundCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CHOOSE ICONIC AVATAR',
                  style: TellyTypography.titleMedium(color: TellyColors.textPrimary),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _iconicAvatars.map((icon) {
                    final isSelected = _selectedAvatarIcon == icon;
                    return ActionChip(
                      label: Text(icon),
                      backgroundColor: isSelected ? TellyColors.phosphorLime.withValues(alpha: 0.2) : TellyColors.backgroundSurface,
                      side: BorderSide(
                        color: isSelected ? TellyColors.phosphorLime : TellyColors.borderGlass,
                      ),
                      labelStyle: TextStyle(
                        color: isSelected ? TellyColors.phosphorLime : TellyColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                      onPressed: () {
                        setState(() {
                          _selectedAvatarIcon = icon;
                        });
                        Navigator.of(ctx).pop();
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TellyColors.backgroundCanvasOled,
      appBar: AppBar(
        backgroundColor: TellyColors.backgroundCanvasOled,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: TellyColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'EDIT PROFILE',
          style: TellyTypography.titleMedium(color: TellyColors.textPrimary).copyWith(letterSpacing: 1.2),
        ),
        actions: [
          TextButton(
            onPressed: _saveProfile,
            child: Text(
              'Save ✓',
              style: TellyTypography.labelLarge(color: TellyColors.phosphorLime).copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        children: [
          // 1. Avatar & Backdrop Header
          Center(
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 46,
                      backgroundColor: TellyColors.backgroundCard,
                      child: Text(
                        _selectedAvatarIcon != null ? _selectedAvatarIcon!.split(' ').first : '👤',
                        style: const TextStyle(fontSize: 40),
                      ),
                    ),
                    InkWell(
                      onTap: _showAvatarPicker,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: TellyColors.phosphorLime,
                          shape: BoxShape.circle,
                          border: Border.all(color: TellyColors.backgroundCanvasOled, width: 2),
                        ),
                        child: const Icon(Icons.camera_alt, color: Colors.black, size: 16),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _showAvatarPicker,
                  child: Text(
                    'Change Iconic Avatar',
                    style: TellyTypography.caption(color: TellyColors.phosphorLime),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 2. Display Name
          _buildFieldHeader('DISPLAY NAME'),
          _buildTextField(
            controller: _displayNameController,
            hint: 'Your display name',
          ),
          const SizedBox(height: 16),

          // 3. Handle
          _buildFieldHeader('HANDLE'),
          _buildTextField(
            controller: _handleController,
            prefixText: '@',
            hint: 'handle',
          ),
          const SizedBox(height: 4),
          Text(
            'Changing your handle may break existing referral and profile links.',
            style: TellyTypography.caption(color: TellyColors.textTertiary),
          ),
          const SizedBox(height: 16),

          // 4. Bio / Manifesto
          _buildFieldHeader('BIO / TV MANIFESTO (MAX 160 CHARS)'),
          _buildTextField(
            controller: _bioController,
            hint: 'Your cinematic bio...',
            maxLines: 3,
            maxLength: 160,
            onChanged: (val) => setState(() {}),
          ),
          const SizedBox(height: 16),

          // 5. Favorite Creator
          _buildFieldHeader('FAVORITE SHOWRUNNER / CREATOR'),
          _buildTextField(
            controller: _creatorController,
            hint: 'e.g. Jesse Armstrong, Vince Gilligan',
          ),
          const SizedBox(height: 24),

          // 6. Curate Top 3 Profile Showcases
          _buildSectionTitle('TOP 3 PROFILE SHOWCASE'),
          Text(
            'Pinned to the hero banner of your public profile.',
            style: TellyTypography.caption(color: TellyColors.textSecondary),
          ),
          const SizedBox(height: 12),
          ...List.generate(3, (index) {
            final slotNumber = index + 1;
            final currentTitle = index < _top3.length ? _top3[index] : 'Empty Slot';
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: TellyColors.backgroundCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: TellyColors.borderGlass),
              ),
              child: Row(
                children: [
                  TellyNeonBadge(
                    label: '#$slotNumber',
                    variant: TellyBadgeVariant.neutral,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      currentTitle,
                      style: TellyTypography.bodyMedium(color: TellyColors.textPrimary),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, color: TellyColors.textTertiary, size: 18),
                    onPressed: () => _editShowcaseSlot(index),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 24),

          // 7. Privacy Mode Selector
          _buildSectionTitle('ACCOUNT VISIBILITY'),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: TellyColors.backgroundCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: TellyColors.borderGlass),
            ),
            child: Column(
              children: [
                _buildRadioTile(
                  title: 'Public',
                  subtitle: 'Anyone can see your Canon, follow, & compare taste.',
                  value: 'PUBLIC',
                ),
                const Divider(color: TellyColors.borderGlass),
                _buildRadioTile(
                  title: 'Friends Only (Private)',
                  subtitle: 'Requires follow approval to view your ratings & taste match.',
                  value: 'FRIENDS_ONLY',
                ),
                const Divider(color: TellyColors.borderGlass),
                _buildRadioTile(
                  title: 'Ghost Mode',
                  subtitle: 'Hidden from global search. Direct link only.',
                  value: 'GHOST',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 8. Module Privacy Toggles
          _buildSectionTitle('MODULE PRIVACY & BOUNDARIES'),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: TellyColors.backgroundCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: TellyColors.borderGlass),
            ),
            child: Column(
              children: [
                _buildSwitchRow(
                  title: 'Show TV Graveyard on Profile',
                  value: _showGraveyard,
                  onChanged: (val) => setState(() => _showGraveyard = val),
                ),
                const Divider(color: TellyColors.borderGlass),
                _buildSwitchRow(
                  title: 'Allow Co-Watch "Two-to-Watch" Invites',
                  value: _allowCoWatch,
                  onChanged: (val) => setState(() => _allowCoWatch = val),
                ),
                const Divider(color: TellyColors.borderGlass),
                _buildSwitchRow(
                  title: 'Auto-Blur Potential Spoilers in Reviews',
                  value: _autoBlurSpoilers,
                  onChanged: (val) => setState(() => _autoBlurSpoilers = val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          TellyPrimaryButton(
            label: 'Save Profile Changes',
            onPressed: _saveProfile,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _editShowcaseSlot(int index) {
    final controller = TextEditingController(
      text: index < _top3.length ? _top3[index] : '',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TellyColors.backgroundCard,
        title: Text(
          'Edit Showcase #${index + 1}',
          style: const TextStyle(color: TellyColors.textPrimary),
        ),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: TellyColors.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Enter title (e.g. Succession)',
            hintStyle: TextStyle(color: TellyColors.textTertiary),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: TellyColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: TellyColors.phosphorLime),
            onPressed: () {
              setState(() {
                if (index < _top3.length) {
                  _top3[index] = controller.text;
                } else {
                  _top3.add(controller.text);
                }
              });
              Navigator.of(ctx).pop();
            },
            child: const Text('Confirm', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Text(
        title,
        style: TellyTypography.labelSmall(color: TellyColors.textSecondary).copyWith(
          letterSpacing: 1.0,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TellyTypography.labelLarge(color: TellyColors.textPrimary).copyWith(
          letterSpacing: 1.0,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    String? hint,
    String? prefixText,
    int maxLines = 1,
    int? maxLength,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      style: const TextStyle(color: TellyColors.textPrimary),
      onChanged: onChanged,
      decoration: InputDecoration(
        filled: true,
        fillColor: TellyColors.backgroundCard,
        prefixText: prefixText,
        prefixStyle: const TextStyle(color: TellyColors.phosphorLime, fontWeight: FontWeight.bold),
        hintText: hint,
        hintStyle: const TextStyle(color: TellyColors.textTertiary),
        counterStyle: const TextStyle(color: TellyColors.textTertiary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: TellyColors.borderGlass),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: TellyColors.borderGlass),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: TellyColors.phosphorLime),
        ),
      ),
    );
  }

  Widget _buildRadioTile({
    required String title,
    required String subtitle,
    required String value,
  }) {
    final isSelected = _visibilityMode == value;
    return InkWell(
      onTap: () => setState(() => _visibilityMode = value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? TellyColors.phosphorLime : TellyColors.textTertiary,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TellyTypography.bodyMedium(
                      color: isSelected ? TellyColors.phosphorLime : TellyColors.textPrimary,
                    ).copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TellyTypography.caption(color: TellyColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchRow({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: TellyTypography.bodyMedium(color: TellyColors.textPrimary),
            ),
          ),
          Switch.adaptive(
            value: value,
            activeThumbColor: TellyColors.phosphorLime,
            activeTrackColor: TellyColors.phosphorLime.withValues(alpha: 0.3),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
