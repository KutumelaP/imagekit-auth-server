import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../widgets/safe_network_image.dart';
import 'simple_store_profile_screen.dart';

class MyStoresScreen extends StatefulWidget {
	const MyStoresScreen({super.key});

	@override
	State<MyStoresScreen> createState() => _MyStoresScreenState();
}

enum _SortMode { recent, name }

class _MyStoresScreenState extends State<MyStoresScreen> {
	final TextEditingController _searchController = TextEditingController();
	bool _alertsOnly = false;
	_SortMode _sortMode = _SortMode.recent;
	final Set<String> _selected = <String>{};

	User? get _user => FirebaseAuth.instance.currentUser;

	@override
	void dispose() {
		_searchController.dispose();
		super.dispose();
	}

	@override
	Widget build(BuildContext context) {
		if (_user == null) {
			return Scaffold(
				appBar: AppBar(title: const Text('My Stores')),
				body: const Center(child: Text('Please login to see followed stores')),
			);
		}

		final followsRef = FirebaseFirestore.instance
			.collection('users')
			.doc(_user!.uid)
			.collection('follows')
			.orderBy('createdAt', descending: true);

		return Scaffold(
			appBar: AppBar(
				backgroundColor: AppTheme.deepTeal,
				foregroundColor: Colors.white,
				title: _selected.isEmpty
					? const Text('My Stores')
					: Text('${_selected.length} selected'),
				actions: [
					if (_selected.isNotEmpty)
						IconButton(
							tooltip: 'Enable alerts for selected',
							icon: const Icon(Icons.notifications_active),
							onPressed: () => _batchToggleAlerts(enable: true),
						),
					if (_selected.isNotEmpty)
						IconButton(
							tooltip: 'Disable alerts for selected',
							icon: const Icon(Icons.notifications_off),
							onPressed: () => _batchToggleAlerts(enable: false),
						),
					PopupMenuButton<_SortMode>(
						initialValue: _sortMode,
						onSelected: (m) => setState(() => _sortMode = m),
						itemBuilder: (ctx) => const [
							PopupMenuItem(value: _SortMode.recent, child: Text('Recently followed')),
							PopupMenuItem(value: _SortMode.name, child: Text('A–Z')),
						],
					)
				],
			),
			body: RefreshIndicator(
				onRefresh: () async => setState(() {}),
				child: Column(
					children: [
						Padding(
							padding: const EdgeInsets.all(12),
							child: _buildToolbar(context),
						),
						Expanded(
							child: StreamBuilder<QuerySnapshot>(
								stream: followsRef.snapshots(),
								builder: (context, snapshot) {
									if (snapshot.connectionState == ConnectionState.waiting) {
										return _buildShimmerGrid(context);
									}
									if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
										return _buildEmptyState(context);
									}

									var docs = snapshot.data!.docs;
									final q = _searchController.text.trim().toLowerCase();
									if (_alertsOnly) {
										docs = docs.where((d) => ((d.data() as Map<String, dynamic>)['notify'] as bool?) ?? true).toList();
									}
									if (q.isNotEmpty) {
										docs = docs.where((d) {
											final data = d.data() as Map<String, dynamic>;
											final name = (data['storeName'] as String? ?? '').toLowerCase();
											return name.contains(q);
										}).toList();
									}
									if (_sortMode == _SortMode.name) {
										docs.sort((a, b) {
											final da = a.data() as Map<String, dynamic>;
											final db = b.data() as Map<String, dynamic>;
											return (da['storeName'] as String? ?? '').compareTo(db['storeName'] as String? ?? '');
										});
									}

														return ListView.separated(
															padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
															itemCount: docs.length,
															separatorBuilder: (_, __) => const SizedBox(height: 12),
															itemBuilder: (ctx, i) {
											final data = docs[i].data() as Map<String, dynamic>;
											final storeId = data['storeId'] as String?;
											final storeName = data['storeName'] as String? ?? 'Store';
											final notify = (data['notify'] as bool?) ?? true;
											if (storeId == null) return const SizedBox.shrink();
																return Center(
																	child: ConstrainedBox(
																		constraints: const BoxConstraints(maxWidth: 720),
																		child: _FollowedStoreCard(
																			storeId: storeId,
																			storeName: storeName,
																			notify: notify,
																			selected: _selected.contains(storeId),
																			onToggleNotify: () => _toggleNotify(storeId, notify),
																			onOpen: () => _openStore(storeId),
																			onChat: (contact, name) => _openWhatsApp(contact, name),
																			onShare: () => _shareStore(storeId, storeName),
																			onLongPress: () => _toggleSelected(storeId),
																			onTapSelectMode: () => _selected.isNotEmpty ? _toggleSelected(storeId) : _openStore(storeId),
																		),
																	),
																);
															},
														);
								},
							),
						),
					],
				),
			),
		);
	}

	Widget _buildToolbar(BuildContext context) {
		return Column(
			crossAxisAlignment: CrossAxisAlignment.stretch,
			children: [
				Container(
					decoration: BoxDecoration(
						color: Colors.white,
						borderRadius: BorderRadius.circular(12),
						boxShadow: [
							BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
						],
					),
					padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
					child: Row(
						children: [
							const Icon(Icons.search, color: AppTheme.breeze),
							const SizedBox(width: 8),
							Expanded(
								child: TextField(
									controller: _searchController,
									decoration: const InputDecoration(
										hintText: 'Search followed stores',
										border: InputBorder.none,
									),
									onChanged: (_) => setState(() {}),
								),
							),
							if (_searchController.text.isNotEmpty)
								IconButton(
									icon: const Icon(Icons.close),
									onPressed: () => setState(() => _searchController.clear()),
								),
						],
					),
				),
				const SizedBox(height: 8),
				Wrap(
					spacing: 8,
					runSpacing: 8,
					children: [
						FilterChip(
							selected: _alertsOnly,
							label: const Text('With alerts'),
							onSelected: (v) => setState(() => _alertsOnly = v),
						),
					],
				),
			],
		);
	}

	Widget _buildShimmerGrid(BuildContext context) {
		return ListView.separated(
			padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
			itemCount: 6,
			separatorBuilder: (_, __) => const SizedBox(height: 12),
			itemBuilder: (ctx, i) {
				return Center(
					child: ConstrainedBox(
						constraints: const BoxConstraints(maxWidth: 720),
						child: Container(
							height: 130,
							decoration: BoxDecoration(
								color: Colors.grey.shade200,
								borderRadius: BorderRadius.circular(16),
							),
						),
					),
				);
			},
		);
	}

	Widget _buildEmptyState(BuildContext context) {
		return Center(
			child: Padding(
				padding: const EdgeInsets.all(24),
				child: Column(
					mainAxisSize: MainAxisSize.min,
					children: [
						Icon(Icons.favorite_border, size: 72, color: AppTheme.breeze),
						const SizedBox(height: 12),
						const Text('No followed stores yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
						const SizedBox(height: 6),
						const Text('Follow stores you love to get alerts and quick access.', textAlign: TextAlign.center),
						const SizedBox(height: 16),
						ElevatedButton.icon(
							style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
							onPressed: () => Navigator.pop(context),
							icon: const Icon(Icons.explore),
							label: const Text('Discover stores'),
						),
					],
				),
			),
		);
	}

	Future<void> _toggleNotify(String storeId, bool current) async {
		if (_user == null) return;
		final ref = FirebaseFirestore.instance
			.collection('users')
			.doc(_user!.uid)
			.collection('follows')
			.doc(storeId);
		await ref.set({'notify': !current}, SetOptions(merge: true));
		if (!mounted) return;
		ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(!current ? 'Alerts enabled' : 'Alerts disabled')));
	}

	void _toggleSelected(String storeId) {
		setState(() {
			if (_selected.contains(storeId)) {
				_selected.remove(storeId);
			} else {
				_selected.add(storeId);
			}
		});
	}

	Future<void> _batchToggleAlerts({required bool enable}) async {
		if (_user == null || _selected.isEmpty) return;
		final batch = FirebaseFirestore.instance.batch();
		for (final storeId in _selected) {
			final ref = FirebaseFirestore.instance
				.collection('users')
				.doc(_user!.uid)
				.collection('follows')
				.doc(storeId);
			batch.set(ref, {'notify': enable}, SetOptions(merge: true));
		}
		await batch.commit();
		if (!mounted) return;
		setState(() => _selected.clear());
		ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(enable ? 'Alerts enabled' : 'Alerts disabled')));
	}

	Future<void> _openStore(String storeId) async {
		final storeSnap = await FirebaseFirestore.instance.collection('users').doc(storeId).get();
		if (!mounted) return;
		if (storeSnap.exists) {
			final data = storeSnap.data()!..putIfAbsent('storeId', () => storeId);
			Navigator.push(context, MaterialPageRoute(builder: (_) => SimpleStoreProfileScreen(store: data)));
		}
	}

	Future<void> _shareStore(String storeId, String storeName) async {
		final base = const String.fromEnvironment('PUBLIC_BASE_URL', defaultValue: 'https://yourdomain.com');
		final url = '$base/store/$storeId';
		await Share.share('Check out $storeName on Mzansi Marketplace\n$url');
	}

	Future<void> _openWhatsApp(String? contact, String storeName) async {
		if (contact == null || contact.isEmpty) {
			ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No WhatsApp contact found for this store')));
			return;
		}
		String phone = contact.replaceAll(RegExp(r'[^\d+]'), '');
		if (!phone.startsWith('+')) {
			if (phone.startsWith('0')) phone = phone.substring(1);
			phone = '+27$phone';
		}
		final digits = phone.replaceAll('+', '');
		final msg = 'Hi $storeName, I found your store on Mzansi Marketplace and would like to chat.';
		final native = Uri.parse('whatsapp://send?phone=$digits&text=${Uri.encodeComponent(msg)}');
		if (await canLaunchUrl(native)) {
			final ok = await launchUrl(native, mode: LaunchMode.externalNonBrowserApplication);
			if (ok) return;
		}
		final wa = Uri.https('wa.me', '/$digits', {'text': msg});
		if (await canLaunchUrl(wa)) {
			final ok = await launchUrl(wa, mode: LaunchMode.externalApplication);
			if (ok) return;
		}
		final api = Uri.https('api.whatsapp.com', '/send', {'phone': digits, 'text': msg});
		if (await canLaunchUrl(api)) {
			final ok = await launchUrl(api, mode: LaunchMode.externalApplication);
			if (ok) return;
		}
		final store = Uri.parse('market://details?id=com.whatsapp');
		if (await canLaunchUrl(store)) {
			final ok = await launchUrl(store, mode: LaunchMode.externalApplication);
			if (ok) return;
		}
		final storeHttp = Uri.parse('https://play.google.com/store/apps/details?id=com.whatsapp');
		if (await canLaunchUrl(storeHttp)) {
			final ok = await launchUrl(storeHttp, mode: LaunchMode.externalApplication);
			if (ok) return;
		}
		final appStore = Uri.parse('https://apps.apple.com/app/whatsapp-messenger/id310633997');
		if (await canLaunchUrl(appStore)) {
			final ok = await launchUrl(appStore, mode: LaunchMode.externalApplication);
			if (ok) return;
		}
		if (!mounted) return;
		showDialog(
			context: context,
			builder: (ctx) => Dialog(
				child: Padding(
					padding: const EdgeInsets.all(16),
					child: Column(
						mainAxisSize: MainAxisSize.min,
						crossAxisAlignment: CrossAxisAlignment.start,
						children: [
							const Text('Open WhatsApp', style: TextStyle(fontWeight: FontWeight.bold)),
							const SizedBox(height: 8),
							const Text("We couldn't open WhatsApp automatically. Copy the number and try manually."),
							const SizedBox(height: 8),
							SelectableText('Number: $phone'),
							const SizedBox(height: 12),
							Row(
								mainAxisAlignment: MainAxisAlignment.end,
								children: [
									TextButton(
										onPressed: () async {
											await Clipboard.setData(ClipboardData(text: phone));
											if (context.mounted) Navigator.of(ctx).pop();
										},
										child: const Text('Copy number'),
									),
									TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
								],
							),
						],
					),
				),
			),
		);
	}
}

class _FollowedStoreCard extends StatelessWidget {
	final String storeId;
	final String storeName;
	final bool notify;
	final bool selected;
	final VoidCallback onToggleNotify;
	final VoidCallback onOpen;
	final void Function(String? contact, String name) onChat;
	final VoidCallback onShare;
	final VoidCallback onLongPress;
	final VoidCallback onTapSelectMode;

	const _FollowedStoreCard({
		super.key,
		required this.storeId,
		required this.storeName,
		required this.notify,
		required this.selected,
		required this.onToggleNotify,
		required this.onOpen,
		required this.onChat,
		required this.onShare,
		required this.onLongPress,
		required this.onTapSelectMode,
	});

	@override
	Widget build(BuildContext context) {
		return InkWell(
			onLongPress: onLongPress,
			onTap: onTapSelectMode,
			borderRadius: BorderRadius.circular(16),
			child: Container(
				decoration: BoxDecoration(
					color: Colors.white,
					borderRadius: BorderRadius.circular(16),
					boxShadow: [
						BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 6)),
					],
					border: selected ? Border.all(color: AppTheme.primaryGreen, width: 2) : null,
				),
				padding: const EdgeInsets.all(12),
				child: Column(
					crossAxisAlignment: CrossAxisAlignment.start,
					children: [
						Row(
							children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: SizedBox(
                                    width: 48,
                                    height: 48,
                                    child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
											stream: FirebaseFirestore.instance.collection('users').doc(storeId).snapshots(),
											builder: (context, snap) {
												final img = (snap.data?.data()?['profileImageUrl'] as String?) ?? '';
												if (img.isEmpty) {
													return Container(
														color: AppTheme.deepTeal.withOpacity(0.08),
														child: const Icon(Icons.storefront, color: AppTheme.deepTeal),
													);
												}
                                                return SafeNetworkImage(imageUrl: img, fit: BoxFit.cover);
                                              },
                                            ),
                                  ),
                                ),
								const SizedBox(width: 10),
								Expanded(
									child: Column(
										crossAxisAlignment: CrossAxisAlignment.start,
										children: [
											Text(storeName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
											StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
												stream: FirebaseFirestore.instance.collection('users').doc(storeId).snapshots(),
												builder: (context, snap) {
													final data = snap.data?.data() ?? const {};
													final category = (data['storeCategory'] as String?) ?? '';
													final followers = (data['followers'] as num?)?.toInt() ?? 0;
													final rating = (data['rating'] as num?)?.toDouble() ?? 0.0;
											final verified = (data['verified'] as bool?) ?? (data['isVerified'] as bool?) ?? false;
											return Wrap(
													spacing: 8,
													runSpacing: 4,
													crossAxisAlignment: WrapCrossAlignment.center,
													children: [
														if (category.isNotEmpty)
															Text(category, style: TextStyle(color: Colors.grey.shade600), overflow: TextOverflow.ellipsis),
														if (verified)
															LayoutBuilder(
																builder: (context, constraints) {
																	final isVeryTight = constraints.maxWidth < 60;
																	return Container(
																		padding: EdgeInsets.symmetric(horizontal: isVeryTight ? 4 : 8, vertical: 4),
																		decoration: BoxDecoration(
																			color: AppTheme.primaryGreen.withOpacity(0.12),
																			borderRadius: BorderRadius.circular(10),
																		),
																		child: isVeryTight
																			? const Icon(Icons.verified_rounded, color: AppTheme.primaryGreen, size: 12)
																			: const Row(
																				mainAxisSize: MainAxisSize.min,
																				children: [
																					Icon(Icons.verified_rounded, color: AppTheme.primaryGreen, size: 14),
																					SizedBox(width: 4),
																					Text('Verified', style: TextStyle(color: AppTheme.primaryGreen, fontSize: 11, fontWeight: FontWeight.w600)),
																				],
																			),
																	);
																},
															),
														Wrap(
															spacing: 6,
															runSpacing: 2,
															crossAxisAlignment: WrapCrossAlignment.center,
															children: [
																Icon(Icons.star, color: Colors.amber.shade600, size: 16),
																Text(rating > 0 ? rating.toStringAsFixed(1) : '0.0', style: TextStyle(color: Colors.grey.shade700)),
																const Icon(Icons.favorite, color: Colors.red, size: 16),
																Text('$followers', style: TextStyle(color: Colors.grey.shade700)),
															],
														),
													],
											);
											},
										),
									],
								),
							),
							IconButton(
								tooltip: notify ? 'Disable alerts' : 'Enable alerts',
								icon: Icon(notify ? Icons.notifications_active : Icons.notifications_off, color: notify ? AppTheme.primaryGreen : Colors.grey),
								onPressed: onToggleNotify,
							),
						],
					),
						const SizedBox(height: 12),
						LayoutBuilder(
							builder: (ctx, constraints) {
								final isUltraNarrow = constraints.maxWidth < 180;
								return Row(
									children: [
										Expanded(
											child: isUltraNarrow
												? OutlinedButton(
													onPressed: () async {
														final snap = await FirebaseFirestore.instance.collection('users').doc(storeId).get();
														final contact = snap.data()?['contact'] as String?;
														onChat(contact, storeName);
													},
													style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(vertical: 8)),
													child: const Icon(Icons.chat, size: 18),
												)
												: OutlinedButton.icon(
													onPressed: () async {
														final snap = await FirebaseFirestore.instance.collection('users').doc(storeId).get();
														final contact = snap.data()?['contact'] as String?;
														onChat(contact, storeName);
													},
													icon: const Icon(Icons.chat, size: 18),
													label: const Text('Chat'),
													style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(vertical: 8)),
												),
										),
										const SizedBox(width: 8),
										Expanded(
											child: isUltraNarrow
												? ElevatedButton(
													onPressed: onOpen,
													style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen, minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(vertical: 8)),
													child: const Icon(Icons.storefront, size: 18, color: Colors.white),
												)
												: ElevatedButton.icon(
													style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen, minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(vertical: 8)),
													onPressed: onOpen,
													icon: const Icon(Icons.storefront, size: 18),
													label: const Text('View'),
												),
										),
									],
								);
							},
						),
					const SizedBox(height: 8),
					Row(
						children: [
							TextButton.icon(onPressed: onShare, icon: const Icon(Icons.share), label: const Text('Share')),
						],
					),
				],
				),
			),
		);
	}
}



