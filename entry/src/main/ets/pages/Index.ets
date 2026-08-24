import picker from '@ohos.file.picker';
import fs from '@ohos.file.fs';
import util from '@ohos.util';
import { apiService } from '../common/ApiService';
import {
  AdminStats,
  AdminUser,
  CATEGORIES,
  CATEGORY_FILTERS,
  LostFoundItem,
  MapStation,
  MessageNotice,
  SOURCE_FILTERS,
  UserProfile
} from '../model/LostFoundItem';

@Entry
@Component
struct Index {
  @State isLoggedIn: boolean = false;
  @State currentTab: string = 'home';
  @State itemFilter: string = '全部';
  @State sourceFilter: string = '全部';
  @State keyword: string = '';
  @State toastText: string = '';
  @State toastVisible: boolean = false;
  @State loading: boolean = false;
  @State errorText: string = '';
  @State pressedKey: string = '';

  @State loginRole: string = 'user';
  @State loginName: string = '';
  @State loginAccount: string = '';
  @State loginPassword: string = '';
  @State loginError: string = '';
  @State user: UserProfile = this.emptyUser();

  @State items: LostFoundItem[] = [];
  @State stations: MapStation[] = [];
  @State messages: MessageNotice[] = [];
  @State selectedItem: LostFoundItem | undefined = undefined;
  @State contactInfo: string = '';
  @State claimAnswer: string = '';
  @State claimNote: string = '';
  @State profileMode: string = 'summary';

  @State publishType: string = 'found';
  @State formTitle: string = '';
  @State formCategory: string = '证件';
  @State formLocation: string = '';
  @State formTime: string = '';
  @State formDescription: string = '';
  @State formContactName: string = '';
  @State formContactPhone: string = '';
  @State formQuestion: string = '';
  @State formAnswer: string = '';
  @State selectedImageUri: string = '';
  @State uploadedImageUrl: string = '';
  @State privacyOn: boolean = true;

  // 管理员页面状态
  @State adminStats: AdminStats | undefined = undefined;
  @State adminUsers: AdminUser[] = [];
  @State adminItems: LostFoundItem[] = [];
  @State adminTab: string = 'stats';
  @State adminEditItemId: number = 0;
  @State adminEditUserId: number = 0;

  // 独立子页面状态
  @State myItems: LostFoundItem[] = [];
  @State myItemsTitle: string = '';
  @State verificationItems: LostFoundItem[] = [];

  private toastVersion: number = 0;

  emptyUser(): UserProfile {
    return {
      id: 0,
      name: '',
      account: '',
      password: '',
      role: 'user',
      avatarText: '拾',
      verification: '',
      trustScore: 0,
      publishingCount: 0,
      recoveredCount: 0,
      returnedCount: 0,
      createdAt: 0
    };
  }

  @State userRole: string = 'user';

  async login(): Promise<void> {
    if (this.loginAccount.trim().length === 0) {
      this.loginError = '请输入账号';
      return;
    }
    if (this.loginPassword.trim().length === 0) {
      this.loginError = '请输入密码';
      return;
    }
    if (this.loginRole === 'user' && this.loginName.trim().length === 0) {
      this.loginError = '请输入昵称';
      return;
    }
    this.loading = true;
    this.loginError = '';
    try {
      const result = await apiService.login(this.loginName.trim(), this.loginAccount.trim(), this.loginPassword.trim(), this.loginRole);
      this.user = result.user;
      this.userRole = result.user.role;
      this.isLoggedIn = true;
      this.showToast(`欢迎回来，${this.user.name}`);
      await this.loadAll();
    } catch (err) {
      const msg = String(err);
      if (msg.includes('密码错误')) {
        this.loginError = '密码错误';
      } else if (msg.includes('不是管理员')) {
        this.loginError = '该账号不是管理员';
      } else if (msg.includes('不存在')) {
        this.loginError = '管理员账号不存在';
      } else {
        this.loginError = '登录失败，请检查后端服务';
      }
    }
    this.loading = false;
  }

  async loadAll(): Promise<void> {
    if (this.user.id === 0) {
      return;
    }
    this.errorText = '';
    try {
      this.items = await apiService.listItems(this.user.id, this.itemFilter, this.keyword);
      this.stations = await apiService.listStations(this.sourceFilter);
      this.profileMode = 'summary';
      this.user = await apiService.getProfile(this.user.id);
      this.userRole = this.user.role;
      this.messages = await apiService.listMessages(this.user.id);
      if (this.userRole === 'admin') {
        await this.loadAdminData();
      }
    } catch (err) {
      this.errorText = '后端服务未连接，请先在 server 目录运行 npm run dev';
    }
  }

  async loadAdminData(): Promise<void> {
    try {
      this.adminStats = await apiService.adminGetStats(this.user.id);
      this.adminUsers = await apiService.adminGetUsers(this.user.id);
      this.adminItems = await apiService.adminGetItems(this.user.id);
    } catch (err) {
      this.showToast('管理员数据加载失败');
    }
  }

  async refreshItems(): Promise<void> {
    if (this.user.id === 0) {
      return;
    }
    try {
      this.items = await apiService.listItems(this.user.id, this.itemFilter, this.keyword);
    } catch (err) {
      this.showToast('线索加载失败');
    }
  }

  async openDetailById(itemId: number): Promise<void> {
    if (itemId <= 0) {
      this.showToast('该站点暂无关联启事');
      return;
    }
    try {
      this.selectedItem = await apiService.getItem(this.user.id, itemId);
      this.claimAnswer = '';
      this.claimNote = '';
      this.contactInfo = '';
      this.currentTab = 'detail';
    } catch (err) {
      this.showToast('详情加载失败');
    }
  }

  async openDetail(item: LostFoundItem): Promise<void> {
    await this.openDetailById(item.id);
  }

  async submitItem(): Promise<void> {
    if (this.formTitle.trim().length === 0 || this.formLocation.trim().length === 0 ||
      this.formDescription.trim().length === 0 || this.formContactName.trim().length === 0 ||
      this.formContactPhone.trim().length === 0) {
      this.showToast('请补全发布信息');
      return;
    }
    try {
      await apiService.createItem({
        userId: this.user.id,
        type: this.publishType,
        title: this.formTitle.trim(),
        category: this.formCategory,
        source: '校园',
        location: this.formLocation.trim(),
        distance: '新发布',
        eventTime: this.formTime.trim() || '刚刚',
        description: this.formDescription.trim(),
        contactName: this.formContactName.trim(),
        contactPhone: this.formContactPhone.trim(),
        privacyNote: this.privacyOn ? '隐藏完整证件号，仅通过特征问答核验' : '发布者已关闭隐私遮罩',
        verificationQuestion: this.formQuestion.trim() || '请描述物品的关键特征。',
        verificationAnswer: this.formAnswer.trim() || '特征正确',
        imageUrl: this.uploadedImageUrl
      });
      this.showToast('发布成功，已进入聚合线索流');
      this.formTitle = '';
      this.formLocation = '';
      this.formTime = '';
      this.formDescription = '';
      this.formContactName = '';
      this.formContactPhone = '';
      this.formQuestion = '';
      this.formAnswer = '';
      this.selectedImageUri = '';
      this.uploadedImageUrl = '';
      this.currentTab = 'home';
      this.itemFilter = '全部';
      await this.loadAll();
    } catch (err) {
      this.showToast('发布失败，请检查后端服务');
    }
  }

  async toggleFavorite(): Promise<void> {
    if (this.selectedItem === undefined) {
      return;
    }
    try {
      const result = await apiService.toggleFavorite(this.user.id, this.selectedItem.id);
      this.showToast(result.message);
      this.selectedItem = await apiService.getItem(this.user.id, this.selectedItem.id);
      await this.refreshItems();
    } catch (err) {
      this.showToast('收藏操作失败');
    }
  }

  async contactPublisher(): Promise<void> {
    if (this.selectedItem === undefined) {
      return;
    }
    try {
      const result = await apiService.contactPublisher(this.user.id, this.selectedItem.id);
      this.contactInfo = `${result.contactName}：${result.contactPhone}`;
      this.showToast('联系方式已展示并记录到消息');
      this.messages = await apiService.listMessages(this.user.id);
    } catch (err) {
      this.showToast('联系失败');
    }
  }

  async submitClaim(): Promise<void> {
    if (this.selectedItem === undefined) {
      return;
    }
    if (this.claimAnswer.trim().length === 0) {
      this.showToast('请先填写核验答案');
      return;
    }
    try {
      await apiService.submitClaim(this.user.id, this.selectedItem.id, this.claimAnswer.trim(), this.claimNote.trim());
      this.selectedItem = await apiService.getItem(this.user.id, this.selectedItem.id);
      this.showToast('认领申请已提交');
      await this.loadAll();
    } catch (err) {
      this.showToast('认领申请失败');
    }
  }

  async completeReturn(): Promise<void> {
    if (this.selectedItem === undefined) {
      return;
    }
    try {
      this.selectedItem = await apiService.completeReturn(this.user.id, this.selectedItem.id);
      this.showToast('已完成归还/找回闭环');
      await this.loadAll();
    } catch (err) {
      this.showToast('状态更新失败');
    }
  }

  async markMessageRead(message: MessageNotice): Promise<void> {
    try {
      await apiService.markMessageRead(this.user.id, message.id);
      this.messages = await apiService.listMessages(this.user.id);
      if (message.itemId > 0) {
        await this.openDetailById(message.itemId);
      } else {
        this.showToast('消息已读');
      }
    } catch (err) {
      this.showToast('消息处理失败');
    }
  }

  async showMyItems(mode: string): Promise<void> {
    try {
      this.profileMode = mode;
      if (mode === 'mine') {
        this.items = await apiService.listItems(this.user.id, '全部', '', '全部', 'me');
        this.showToast('已显示我的发布');
      } else if (mode === 'favorites') {
        this.items = await apiService.listItems(this.user.id, '全部', '', '全部', '', true);
        this.showToast('已显示我的收藏');
      } else {
        await this.refreshItems();
      }
    } catch (err) {
      this.showToast('加载失败');
    }
  }

  async selectPhoto(): Promise<void> {
    try {
      const options = new picker.PhotoSelectOptions();
      options.MIMEType = picker.PhotoViewMIMETypes.IMAGE_TYPE;
      options.maxSelectNumber = 1;
      const photoPicker = new picker.PhotoViewPicker();
      const result = await photoPicker.select(options);
      if (result.photoUris.length === 0) {
        return;
      }
      const uri = result.photoUris[0];
      this.selectedImageUri = uri;
      this.uploadedImageUrl = '';
      this.showToast('已选择照片，正在上传');
      const base64 = this.readImageAsBase64(uri);
      const upload = await apiService.uploadImage(this.imageFileName(uri), this.imageMimeType(uri), base64);
      this.uploadedImageUrl = upload.imageUrl;
      this.showToast('照片上传成功');
    } catch (err) {
      this.showToast('照片选择或上传失败');
    }
  }

  async adminDeleteItem(itemId: number): Promise<void> {
    try {
      await apiService.adminDeleteItem(this.user.id, itemId);
      this.showToast('启事已删除');
      await this.loadAdminData();
      await this.loadAll();
    } catch (err) {
      this.showToast('删除失败');
    }
  }

  async adminUpdateItemStatus(itemId: number, status: string): Promise<void> {
    try {
      await apiService.updateStatus(this.user.id, itemId, status);
      this.showToast('状态已更新');
      this.adminEditItemId = 0;
      await this.loadAdminData();
      await this.loadAll();
    } catch (err) {
      this.showToast('状态更新失败');
    }
  }

  async adminDeleteUser(targetUserId: number): Promise<void> {
    try {
      await apiService.adminDeleteUser(this.user.id, targetUserId);
      this.showToast('用户已删除');
      this.adminEditUserId = 0;
      await this.loadAdminData();
    } catch (err) {
      this.showToast('删除用户失败');
    }
  }

  async adminUpdateUserRole(targetUserId: number, role: string): Promise<void> {
    try {
      await apiService.adminUpdateUserRole(this.user.id, targetUserId, role);
      this.showToast('角色已更新');
      this.adminEditUserId = 0;
      await this.loadAdminData();
    } catch (err) {
      this.showToast('角色更新失败');
    }
  }

  async deleteMyItem(itemId: number): Promise<void> {
    try {
      await apiService.deleteMyItem(this.user.id, itemId);
      this.showToast('启事已删除');
      await this.loadAll();
    } catch (err) {
      this.showToast('删除失败');
    }
  }

  readImageAsBase64(uri: string): string {
    const file = fs.openSync(uri, fs.OpenMode.READ_ONLY);
    try {
      const stat = fs.statSync(file.fd);
      if (stat.size > 4 * 1024 * 1024) {
        throw new Error('图片不能超过 4MB');
      }
      const buffer = new ArrayBuffer(stat.size);
      fs.readSync(file.fd, buffer);
      const bytes = new Uint8Array(buffer);
      const helper = new util.Base64Helper();
      return helper.encodeToStringSync(bytes);
    } finally {
      fs.closeSync(file);
    }
  }

  imageFileName(uri: string): string {
    const cleanUri = uri.split('?')[0];
    const parts = cleanUri.split('/');
    const rawName = parts.length > 0 ? parts[parts.length - 1] : '';
    return rawName.length > 0 ? rawName : `photo-${Date.now()}.jpg`;
  }

  imageMimeType(uri: string): string {
    const lower = uri.toLowerCase();
    if (lower.endsWith('.png')) {
      return 'image/png';
    }
    if (lower.endsWith('.webp')) {
      return 'image/webp';
    }
    return 'image/jpeg';
  }

  showToast(text: string): void {
    this.toastText = text;
    this.toastVisible = true;
    this.toastVersion += 1;
    const currentVersion = this.toastVersion;
    setTimeout(() => {
      if (this.toastVersion === currentVersion) {
        this.toastVisible = false;
        this.toastText = '';
      }
    }, 2000);
  }

  press(key: string): void {
    this.pressedKey = key;
  }

  release(): void {
    this.pressedKey = '';
  }

  isPressed(key: string): boolean {
    return this.pressedKey === key;
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      if (!this.isLoggedIn) {
        this.LoginPage()
      } else if (this.currentTab === 'detail') {
        this.DetailPage()
      } else if (this.currentTab === 'admin') {
        this.AdminPage()
      } else if (this.currentTab === 'myitems') {
        this.MyItemsPage()
      } else if (this.currentTab === 'verification') {
        this.VerificationPage()
      } else {
        Stack({ alignContent: Alignment.Bottom }) {
          Column() {
            if (this.currentTab === 'home') {
              this.HomePage()
            } else if (this.currentTab === 'map') {
              this.MapPage()
            } else if (this.currentTab === 'publish') {
              this.PublishPage()
            } else if (this.currentTab === 'messages') {
              this.MessagesPage()
            } else {
              this.ProfilePage()
            }
          }
          .width('100%')
          .height('100%')
          .padding({ bottom: this.currentTab === 'publish' ? 0 : 64 })

          if (this.currentTab !== 'publish') {
            this.BottomBar()
          }
        }
      }

      if (this.toastText.length > 0 && this.toastVisible) {
        Text(this.toastText)
          .fontSize(13)
          .fontColor('#FFFFFF')
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })
          .backgroundColor('#1E293B')
          .borderRadius(16)
          .opacity(this.toastVisible ? 0.95 : 0)
          .translate({ y: this.toastVisible ? 0 : 8 })
          .animation({ duration: 150, curve: Curve.EaseOut })
          .margin({ bottom: 80 })
          .onClick(() => {
            this.toastVisible = false;
            this.toastText = '';
          })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F1F5F9')
  }

  // ==================== 登录页 ====================
  @Builder
  LoginPage() {
    Column() {
      Blank()
      Column() {
        // Logo 区域 - 根据角色切换
        Column() {
          Text(this.loginRole === 'admin' ? '管理后台' : '拾见')
            .fontSize(36)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.loginRole === 'admin' ? '#7C3AED' : '#1E293B')
          Text(this.loginRole === 'admin' ? '启事与用户管理平台' : '失物招领与寻物启事聚合平台')
            .fontSize(13)
            .fontColor('#94A3B8')
            .margin({ top: 6 })
        }

        // 角色切换
        Row() {
          Text('普通用户')
            .fontSize(14)
            .fontWeight(this.loginRole === 'user' ? FontWeight.Bold : FontWeight.Normal)
            .fontColor(this.loginRole === 'user' ? '#2563EB' : '#64748B')
            .padding({ left: 20, right: 20, top: 8, bottom: 8 })
            .backgroundColor(this.loginRole === 'user' ? '#EFF6FF' : '#F8FAFC')
            .borderRadius(8)
            .onClick(() => {
              this.loginRole = 'user';
              this.loginError = '';
            })
          Text('管理员')
            .fontSize(14)
            .fontWeight(this.loginRole === 'admin' ? FontWeight.Bold : FontWeight.Normal)
            .fontColor(this.loginRole === 'admin' ? '#7C3AED' : '#64748B')
            .padding({ left: 20, right: 20, top: 8, bottom: 8 })
            .backgroundColor(this.loginRole === 'admin' ? '#F5F3FF' : '#F8FAFC')
            .borderRadius(8)
            .onClick(() => {
              this.loginRole = 'admin';
              this.loginError = '';
            })
        }
        .margin({ top: 28 })
        .backgroundColor('#F1F5F9')
        .borderRadius(10)
        .padding(3)

        // 管理员提示
        if (this.loginRole === 'admin') {
          Row() {
            Text('盾')
              .width(28)
              .height(28)
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor('#7C3AED')
              .textAlign(TextAlign.Center)
              .backgroundColor('#F5F3FF')
              .borderRadius(14)
            Column() {
              Text('管理员模式')
                .fontSize(13)
                .fontWeight(FontWeight.Bold)
                .fontColor('#7C3AED')
              Text('可管理所有启事和注册用户')
                .fontSize(11)
                .fontColor('#A78BFA')
                .margin({ top: 2 })
            }
            .margin({ left: 10 })
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')
          .padding(12)
          .backgroundColor('#FAF5FF')
          .borderRadius(10)
          .margin({ top: 16 })
        }

        // 昵称（仅普通用户）
        if (this.loginRole === 'user') {
          TextInput({ placeholder: '昵称', text: this.loginName })
            .height(44)
            .fontSize(14)
            .backgroundColor('#F8FAFC')
            .borderRadius(10)
            .margin({ top: 20 })
            .onChange((value: string) => {
              this.loginName = value;
            })
        }

        // 账号
        TextInput({ placeholder: this.loginRole === 'admin' ? '管理员账号' : '学号 / 手机号', text: this.loginAccount })
          .height(44)
          .fontSize(14)
          .backgroundColor('#F8FAFC')
          .borderRadius(10)
          .margin({ top: this.loginRole === 'user' ? 10 : 16 })
          .onChange((value: string) => {
            this.loginAccount = value;
          })

        // 密码
        TextInput({ placeholder: '密码', text: this.loginPassword })
          .height(44)
          .fontSize(14)
          .type(InputType.Password)
          .backgroundColor('#F8FAFC')
          .borderRadius(10)
          .margin({ top: 10 })
          .onChange((value: string) => {
            this.loginPassword = value;
          })
          .onSubmit(() => {
            this.login();
          })

        // 错误提示
        if (this.loginError.length > 0) {
          Text(this.loginError)
            .fontSize(12)
            .fontColor('#EF4444')
            .margin({ top: 10 })
            .width('100%')
        }

        // 登录按钮
        Button(this.loading ? '登录中...' : '登录')
          .width('100%')
          .height(42)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .backgroundColor(this.loginRole === 'admin' ? '#7C3AED' : '#2563EB')
          .borderRadius(10)
          .margin({ top: 20 })
          .enabled(!this.loading)
          .onClick(() => {
            this.login();
          })

        // 提示
        Column() {
          if (this.loginRole === 'admin') {
            Text('管理员账号：admin / admin123')
              .fontSize(11)
              .fontColor('#94A3B8')
          } else {
            Text('普通用户账号：20260001 / 123456')
              .fontSize(11)
              .fontColor('#94A3B8')
          }
          if (this.loginRole === 'user') {
            Text('新用户输入昵称和账号密码即可自动注册')
              .fontSize(11)
              .fontColor('#CBD5E1')
              .margin({ top: 4 })
          }
        }
        .margin({ top: 16 })
        .alignItems(HorizontalAlign.Center)
      }
      .width('84%')
      .padding({ left: 24, right: 24, top: 32, bottom: 28 })
      .backgroundColor('#FFFFFF')
      .borderRadius(20)
      .shadow({ radius: 20, color: '#0F172A0D', offsetY: 6 })
      Blank()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.loginRole === 'admin' ? '#F5F3FF' : '#EFF6FF')
  }

  // ==================== 状态栏 ====================
  @Builder
  StatusBar() {
    Blank()
      .height(12)
      .width('100%')
  }

  // ==================== 首页 ====================
  @Builder
  HomePage() {
    Column() {
      this.StatusBar()
      // 顶部标题栏
      Row() {
        Column() {
          Text('拾见')
            .fontSize(26)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1E293B')
          Text('校园 / 城市失物招领聚合平台')
            .fontSize(12)
            .fontColor('#94A3B8')
            .margin({ top: 2 })
        }
        .layoutWeight(1)
      }
      .padding({ left: 20, right: 20, top: 10 })

      // 搜索框 + 搜索按钮
      Row() {
        TextInput({ placeholder: '搜索物品、地点或描述', text: this.keyword })
          .layoutWeight(1)
          .height(38)
          .fontSize(13)
          .backgroundColor('#FFFFFF')
          .borderRadius({ topLeft: 19, bottomLeft: 19, topRight: 0, bottomRight: 0 })
          .onChange((value: string) => {
            this.keyword = value;
          })
          .onSubmit(() => {
            this.refreshItems();
          })
        Button('搜索')
          .height(38)
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .backgroundColor('#2563EB')
          .borderRadius({ topLeft: 0, bottomLeft: 0, topRight: 19, bottomRight: 19 })
          .padding({ left: 16, right: 16 })
          .onClick(async () => {
            await this.refreshItems();
            this.showToast('已搜索');
          })
      }
      .width('90%')
      .margin({ top: 12 })

      // 匹配卡片
      Column() {
        Row() {
          Text(`当前共 ${this.items.length} 条线索`)
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
          Blank()
        }
        Text('浏览附近站点与校内群组来源的失物招领信息，发布启事即可开启智能匹配。')
          .fontSize(12)
          .fontColor('#BFDBFE')
          .lineHeight(18)
          .margin({ top: 6 })
      }
      .width('90%')
      .padding(16)
      .margin({ top: 14 })
      .backgroundColor('#1D4ED8')
      .borderRadius(16)

      this.FilterRow()

      if (this.errorText.length > 0) {
        this.ErrorBanner()
      }

      if (this.items.length === 0) {
        this.EmptyState('暂无线索', '换个关键词，或发布一条新的启事。')
      } else {
        List({ space: 10 }) {
          ForEach(this.items, (item: LostFoundItem) => {
            ListItem() {
              this.ItemCard(item)
            }
          }, (item: LostFoundItem) => item.id.toString())
        }
        .layoutWeight(1)
        .padding({ left: 20, right: 20, top: 4 })
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  FilterRow() {
    Scroll() {
      Row() {
        ForEach(CATEGORY_FILTERS, (filter: string) => {
          Button(filter)
            .height(28)
            .fontSize(12)
            .fontColor(this.itemFilter === filter ? '#2563EB' : '#475569')
            .backgroundColor(this.itemFilter === filter ? '#EFF6FF' : '#FFFFFF')
            .border({ width: this.itemFilter === filter ? 1 : 0, color: '#2563EB' })
            .borderRadius(14)
            .margin({ right: 8 })
            .onClick(async () => {
              this.itemFilter = filter;
              await this.refreshItems();
            })
        }, (filter: string) => filter)
      }
      .padding({ left: 20, right: 20 })
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .height(40)
    .margin({ top: 8 })
  }

  @Builder
  ItemThumb(item: LostFoundItem) {
    if (item.imageUrl.length > 0) {
      Image(item.imageUrl)
        .width(60)
        .height(60)
        .objectFit(ImageFit.Cover)
        .borderRadius(12)
    } else {
      Text(item.category)
        .width(60)
        .height(60)
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor(item.type === 'lost' ? '#B45309' : '#2563EB')
        .textAlign(TextAlign.Center)
        .backgroundColor(item.type === 'lost' ? '#FFF7ED' : '#EFF6FF')
        .borderRadius(12)
    }
  }

  @Builder
  ItemCard(item: LostFoundItem) {
    Row() {
      this.ItemThumb(item)

      Column() {
        Row() {
          Text(item.status)
            .fontSize(10)
            .fontWeight(FontWeight.Bold)
            .fontColor(item.type === 'lost' ? '#B45309' : '#16A34A')
            .padding({ left: 7, right: 7, top: 2, bottom: 2 })
            .backgroundColor(item.type === 'lost' ? '#FEF3C7' : '#DCFCE7')
            .borderRadius(8)
          Blank()
          Text(item.favorite === 1 ? '已收藏' : item.distance)
            .fontSize(10)
            .fontWeight(FontWeight.Bold)
            .fontColor(item.favorite === 1 ? '#EF4444' : '#3B82F6')
        }
        Text(item.title)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1E293B')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 5 })
        Text(`${item.location} · ${item.eventTime}`)
          .fontSize(11)
          .fontColor('#94A3B8')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 3 })
        Row() {
          Text('')
            .height(4)
            .width(`${item.score}%`)
            .backgroundColor(item.type === 'lost' ? '#F59E0B' : item.color)
            .borderRadius(2)
          Text('')
            .height(4)
            .layoutWeight(1)
            .backgroundColor('#E2E8F0')
            .borderRadius(2)
        }
        .margin({ top: 8 })
        Text(`${item.scoreLabel} ${item.score}%`)
          .fontSize(10)
          .fontColor('#94A3B8')
          .alignSelf(ItemAlign.End)
          .margin({ top: 2 })
      }
      .layoutWeight(1)
      .margin({ left: 12 })
    }
    .width('100%')
    .padding(12)
    .backgroundColor('#FFFFFF')
    .borderRadius(14)
    .shadow({ radius: 4, color: '#0F172A08', offsetY: 2 })
    .onClick(async () => {
      await this.openDetail(item);
    })
  }

  // ==================== 发布页 ====================
  @Builder
  PublishPage() {
    Column() {
      this.StatusBar()
      Row() {
        Text('发布启事')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1E293B')
        Blank()
        Button('回首页')
          .height(30)
          .fontSize(12)
          .fontColor('#2563EB')
          .backgroundColor('#FFFFFF')
          .borderRadius(15)
          .padding({ left: 12, right: 12 })
          .onClick(() => {
            this.currentTab = 'home';
          })
      }
      .padding({ left: 20, right: 20, top: 10 })

      Scroll() {
        Column() {
          // 类型切换
          Row() {
            Button('我捡到了')
              .layoutWeight(1)
              .height(38)
              .fontSize(13)
              .fontColor(this.publishType === 'found' ? '#2563EB' : '#64748B')
              .backgroundColor(this.publishType === 'found' ? '#FFFFFF' : '#E2E8F0')
              .borderRadius(19)
              .onClick(() => {
                this.publishType = 'found';
              })
            Button('我丢东西了')
              .layoutWeight(1)
              .height(38)
              .fontSize(13)
              .fontColor(this.publishType === 'lost' ? '#2563EB' : '#64748B')
              .backgroundColor(this.publishType === 'lost' ? '#FFFFFF' : '#E2E8F0')
              .borderRadius(19)
              .onClick(() => {
                this.publishType = 'lost';
              })
          }
          .padding(3)
          .backgroundColor('#E2E8F0')
          .borderRadius(22)
          .margin({ top: 16 })

          Column() {
            // 照片上传
            Text('物品照片')
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1E293B')
              .width('100%')
            Row() {
              if (this.selectedImageUri.length > 0) {
                Image(this.selectedImageUri)
                  .width(100)
                  .height(88)
                  .objectFit(ImageFit.Cover)
                  .borderRadius(12)
              } else {
                Column() {
                  Text('+')
                    .fontSize(28)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#2563EB')
                  Text('添加照片')
                    .fontSize(11)
                    .fontColor('#2563EB')
                    .margin({ top: 4 })
                }
                .width(100)
                .height(88)
                .justifyContent(FlexAlign.Center)
              }
            }
            .width(100)
            .height(88)
            .backgroundColor('#EFF6FF')
            .borderRadius(12)
            .clip(true)
            .margin({ top: 10 })
            .onClick(async () => {
              await this.selectPhoto();
            })

            this.TextField('物品名称', '请输入物品名称', this.formTitle, (value: string) => {
              this.formTitle = value;
            })
            this.CategoryPicker()
            this.TextField('地点', '请输入发现/丢失地点', this.formLocation, (value: string) => {
              this.formLocation = value;
            })
            this.TextField('时间', '如：今天 17:40', this.formTime, (value: string) => {
              this.formTime = value;
            })
            this.TextAreaField('物品描述', '请描述物品特征、认领要求等', this.formDescription, (value: string) => {
              this.formDescription = value;
            })
            this.TextField('核验问题', '请说明颜色、挂件或姓名首字', this.formQuestion, (value: string) => {
              this.formQuestion = value;
            })
            this.TextField('参考答案', '如：蓝色 星形 林', this.formAnswer, (value: string) => {
              this.formAnswer = value;
            })
            this.TextField('联系人', '请输入联系人姓名', this.formContactName, (value: string) => {
              this.formContactName = value;
            })
            this.TextField('联系方式', '手机 / 微信 / 服务台电话', this.formContactPhone, (value: string) => {
              this.formContactPhone = value;
            })

            Row() {
              Text('隐藏完整证件号，仅通过特征问答核验')
                .fontSize(12)
                .fontColor('#16A34A')
                .layoutWeight(1)
              Toggle({ type: ToggleType.Switch, isOn: this.privacyOn })
                .selectedColor('#22C55E')
                .onChange((isOn: boolean) => {
                  this.privacyOn = isOn;
                })
            }
            .padding(10)
            .backgroundColor('#F0FDF4')
            .borderRadius(10)
            .margin({ top: 12 })
          }
          .padding(16)
          .backgroundColor('#FFFFFF')
          .borderRadius(16)
          .margin({ top: 16 })

          Text('发布后将同步聚合到校园墙、物业站点与合作社群渠道。')
            .fontSize(11)
            .fontColor('#CBD5E1')
            .textAlign(TextAlign.Center)
            .margin({ top: 14, bottom: 80 })
        }
        .padding({ left: 20, right: 20 })
      }
      .layoutWeight(1)

      Column() {
        this.FixedSubmitButton('publish', '发布并开启智能匹配', '#2563EB', async () => {
          await this.submitItem();
        })
      }
      .width('100%')
      .height(76)
      .padding({ left: 20, right: 20, top: 10, bottom: 16 })
      .backgroundColor('#F1F5F9')
    }
  }

  // ==================== 详情页 ====================
  @Builder
  DetailPage() {
    Column() {
      this.StatusBar()
      Row() {
        Text('<')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1E293B')
          .onClick(() => {
            this.currentTab = 'home';
          })
        Text('招领详情')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1E293B')
          .margin({ left: 20 })
        Blank()
        Button(this.selectedItem !== undefined && this.selectedItem.favorite === 1 ? '已收藏' : '收藏')
          .height(30)
          .fontSize(12)
          .fontColor('#2563EB')
          .backgroundColor('#FFFFFF')
          .borderRadius(15)
          .padding({ left: 12, right: 12 })
          .onClick(async () => {
            await this.toggleFavorite();
          })
      }
      .padding({ left: 20, right: 20, top: 10 })

      if (this.selectedItem === undefined) {
        this.EmptyState('未选择启事', '请从首页或地图打开详情。')
      } else {
        Scroll() {
          Column() {
            // 图片区域
            Stack() {
              if (this.selectedItem.imageUrl.length > 0) {
                Image(this.selectedItem.imageUrl)
                  .width('100%')
                  .height(200)
                  .objectFit(ImageFit.Cover)
                  .borderRadius(20)
              } else {
                Column() {
                  Text(this.selectedItem.category)
                    .fontSize(20)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#2563EB')
                    .width(160)
                    .height(100)
                    .textAlign(TextAlign.Center)
                    .backgroundColor('#DBEAFE')
                    .borderRadius(20)
                }
                .width('100%')
                .height(200)
                .justifyContent(FlexAlign.Center)
                .backgroundColor('#EFF6FF')
                .borderRadius(20)
              }

              Text(this.selectedItem.status)
                .fontSize(12)
                .fontWeight(FontWeight.Bold)
                .fontColor('#16A34A')
                .padding({ left: 14, right: 14, top: 6, bottom: 6 })
                .backgroundColor('#FFFFFF')
                .borderRadius(14)
                .position({ x: 32, y: 176 })
            }
            .height(210)
            .margin({ top: 16 })

            Text(this.selectedItem.title)
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1E293B')
              .width('100%')
              .margin({ top: 14 })
            Text(`${this.selectedItem.location} · ${this.selectedItem.eventTime} 发布 · ${this.selectedItem.ownerName}`)
              .fontSize(12)
              .fontColor('#94A3B8')
              .width('100%')
              .margin({ top: 6 })
            Text(this.selectedItem.description)
              .fontSize(14)
              .fontColor('#475569')
              .lineHeight(22)
              .width('100%')
              .margin({ top: 14 })

            this.MatchCard()

            // 认领核验
            Column() {
              Text('认领核验')
                .fontSize(15)
                .fontWeight(FontWeight.Bold)
                .fontColor('#1E293B')
                .width('100%')
              Text(this.selectedItem.verificationQuestion)
                .fontSize(12)
                .fontColor('#64748B')
                .lineHeight(18)
                .margin({ top: 6 })
              TextInput({ placeholder: '填写你的答案', text: this.claimAnswer })
                .height(40)
                .backgroundColor('#F8FAFC')
                .borderRadius(10)
                .margin({ top: 10 })
                .onChange((value: string) => {
                  this.claimAnswer = value;
                })
              TextInput({ placeholder: '补充说明，可选', text: this.claimNote })
                .height(40)
                .backgroundColor('#F8FAFC')
                .borderRadius(10)
                .margin({ top: 8 })
                .onChange((value: string) => {
                  this.claimNote = value;
                })
              if (this.selectedItem.claimStatus.length > 0) {
                Text(`我的认领状态：${this.selectedItem.claimStatus}`)
                  .fontSize(12)
                  .fontColor('#2563EB')
                  .margin({ top: 8 })
              }
            }
            .padding(14)
            .backgroundColor('#FFFFFF')
            .borderRadius(14)
            .margin({ top: 14 })

            if (this.contactInfo.length > 0) {
              Text(`联系方式：${this.contactInfo}`)
                .fontSize(13)
                .fontWeight(FontWeight.Bold)
                .fontColor('#2563EB')
                .padding(12)
                .backgroundColor('#EFF6FF')
                .borderRadius(12)
                .margin({ top: 12 })
            }

            // 操作按钮
            Row() {
              Button('我要认领')
                .layoutWeight(1)
                .height(40)
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor('#FFFFFF')
                .backgroundColor('#2563EB')
                .borderRadius(20)
                .onClick(async () => {
                  await this.submitClaim();
                })
              Button('联系发布者')
                .layoutWeight(1)
                .height(40)
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor('#2563EB')
                .backgroundColor('#FFFFFF')
                .border({ width: 1, color: '#CBD5E1' })
                .borderRadius(20)
                .margin({ left: 10 })
                .onClick(async () => {
                  await this.contactPublisher();
                })
            }
            .margin({ top: 20 })

            Button(this.selectedItem.type === 'lost' ? '标记已找回' : '确认已归还')
              .width('100%')
              .height(40)
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
              .backgroundColor('#16A34A')
              .borderRadius(20)
              .margin({ top: 10, bottom: 20 })
              .onClick(async () => {
                await this.completeReturn();
              })

            // 删除自己发布的启事
            if (this.selectedItem !== undefined && this.selectedItem.ownerId === this.user.id) {
              Button('删除此启事')
                .width('100%')
                .height(40)
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor('#EF4444')
                .backgroundColor('#FEF2F2')
                .borderRadius(20)
                .margin({ bottom: 20 })
                .onClick(async () => {
                  const itemId = this.selectedItem!.id;
                  await this.deleteMyItem(itemId);
                  this.selectedItem = undefined;
                  this.currentTab = 'home';
                })
            }
          }
          .padding({ left: 20, right: 20 })
        }
        .layoutWeight(1)
      }
    }
    .height('100%')
  }

  @Builder
  MatchCard() {
    Column() {
      Row() {
        Text('AI')
          .width(30)
          .height(30)
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor('#6366F1')
          .textAlign(TextAlign.Center)
          .backgroundColor('#EEF2FF')
          .borderRadius(10)
        Column() {
          Text('疑似匹配：寻物启事 #A208')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1E293B')
          Text('物品、地点、时间三项高度重合，系统匹配置信度 92%。')
            .fontSize(11)
            .fontColor('#64748B')
            .lineHeight(16)
            .margin({ top: 4 })
        }
        .layoutWeight(1)
        .margin({ left: 10 })
      }
      Row() {
        Text('')
          .height(5)
          .width('78%')
          .backgroundColor('#6366F1')
          .borderRadius(3)
        Text('')
          .height(5)
          .layoutWeight(1)
          .backgroundColor('#E2E8F0')
          .borderRadius(3)
        Text('92%')
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor('#6366F1')
          .margin({ left: 8 })
      }
      .margin({ top: 10 })
    }
    .padding(14)
    .backgroundColor('#FFFFFF')
    .borderRadius(14)
    .margin({ top: 18 })
  }

  // ==================== 地图页 ====================
  @Builder
  MapPage() {
    Column() {
      this.StatusBar()
      Row() {
        Text('附近线索')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1E293B')
        Blank()
        Button('刷新')
          .height(30)
          .fontSize(12)
          .fontColor('#2563EB')
          .backgroundColor('#FFFFFF')
          .borderRadius(15)
          .padding({ left: 12, right: 12 })
          .onClick(async () => {
            this.stations = await apiService.listStations(this.sourceFilter);
            this.showToast('站点已刷新');
          })
      }
      .padding({ left: 20, right: 20, top: 10 })

      Stack() {
        Column() {
          Text('').height(72).width('100%').backgroundColor('#E6F0FF')
          Text('').height(72).width('100%').backgroundColor('#DBEAFE')
          Text('').height(72).width('100%').backgroundColor('#E6F0FF')
        }
        .width('100%')
        .height(200)
        .borderRadius(20)

        ForEach(this.stations, (station: MapStation) => {
          Column() {
            Text('')
              .width(14)
              .height(14)
              .backgroundColor(station.color)
              .borderRadius(7)
            Text(station.name.replace('二楼服务台', '').replace('客服处', ''))
              .fontSize(9)
              .fontColor(station.color)
              .fontWeight(FontWeight.Bold)
          }
          .position({ x: station.mapX * 3, y: station.mapY * 2 })
          .onClick(async () => {
            await this.openDetailById(station.itemId);
          })
        }, (station: MapStation) => station.id.toString())

        Text(`${this.stations.length} 个招领站点 · 18 条附近启事 · 最近 320m`)
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor('#334155')
          .padding({ left: 14, right: 14, top: 8, bottom: 8 })
          .backgroundColor('#FFFFFF')
          .borderRadius(14)
          .position({ x: 20, y: 166 })
      }
      .width('90%')
      .height(226)
      .margin({ top: 14 })
      .alignSelf(ItemAlign.Center)

      Text('按来源筛选')
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1E293B')
        .width('100%')
        .padding({ left: 20, top: 14 })

      Row() {
        ForEach(SOURCE_FILTERS, (source: string) => {
          this.SourceChip(source)
        })
      }
      .padding({ left: 20, right: 16, top: 8 })

      List({ space: 10 }) {
        ForEach(this.stations, (station: MapStation) => {
          ListItem() {
            Row() {
              Text(station.statusText)
                .width(34)
                .height(34)
                .fontSize(13)
                .fontWeight(FontWeight.Bold)
                .fontColor(station.statusText === '招' ? '#22C55E' : '#F59E0B')
                .textAlign(TextAlign.Center)
                .backgroundColor(station.statusText === '招' ? '#DCFCE7' : '#FEF3C7')
                .borderRadius(12)
              Column() {
                Text(station.name)
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#1E293B')
                Text(`${station.itemTitle} · ${station.timeText}`)
                  .fontSize(11)
                  .fontColor('#64748B')
                  .margin({ top: 3 })
              }
              .layoutWeight(1)
              .margin({ left: 10 })
              Text('>')
                .fontSize(16)
                .fontColor('#CBD5E1')
            }
            .padding(12)
            .backgroundColor('#FFFFFF')
            .borderRadius(14)
            .onClick(async () => {
              await this.openDetailById(station.itemId);
            })
          }
        }, (station: MapStation) => station.id.toString())
      }
      .layoutWeight(1)
      .padding({ left: 20, right: 20, top: 12 })
    }
  }

  // ==================== 消息页 ====================
  @Builder
  MessagesPage() {
    Column() {
      this.StatusBar()
      Row() {
        Text('消息')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1E293B')
        Blank()
        Button('全部已读')
          .height(30)
          .fontSize(12)
          .fontColor('#2563EB')
          .backgroundColor('#FFFFFF')
          .borderRadius(15)
          .padding({ left: 12, right: 12 })
          .onClick(async () => {
            for (let index = 0; index < this.messages.length; index += 1) {
              const msg = this.messages[index];
              await apiService.markMessageRead(this.user.id, msg.id);
            }
            this.messages = await apiService.listMessages(this.user.id);
            this.showToast('消息已全部标记已读');
          })
      }
      .padding({ left: 20, right: 20, top: 10 })

      if (this.messages.length === 0) {
        this.EmptyState('暂无消息', '认领、联系和状态变化会出现在这里。')
      } else {
        List({ space: 10 }) {
          ForEach(this.messages, (message: MessageNotice) => {
            ListItem() {
              Row() {
                Text(message.type)
                  .width(40)
                  .height(40)
                  .fontSize(13)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(message.unread === 1 ? '#FFFFFF' : '#2563EB')
                  .textAlign(TextAlign.Center)
                  .backgroundColor(message.unread === 1 ? '#2563EB' : '#EFF6FF')
                  .borderRadius(14)
                Column() {
                  Row() {
                    Text(message.title)
                      .fontSize(14)
                      .fontWeight(FontWeight.Bold)
                      .fontColor('#1E293B')
                      .layoutWeight(1)
                    Text(message.timeText)
                      .fontSize(10)
                      .fontColor('#CBD5E1')
                  }
                  Text(message.content)
                    .fontSize(12)
                    .fontColor('#64748B')
                    .lineHeight(17)
                    .margin({ top: 4 })
                }
                .layoutWeight(1)
                .margin({ left: 10 })
              }
              .padding(12)
              .backgroundColor('#FFFFFF')
              .borderRadius(14)
              .onClick(async () => {
                await this.markMessageRead(message);
              })
            }
          }, (message: MessageNotice) => message.id.toString())
        }
        .layoutWeight(1)
        .padding({ left: 20, right: 20, top: 14 })
      }
    }
  }

  // ==================== 个人中心 ====================
  @Builder
  ProfilePage() {
    Column() {
      this.StatusBar()
      Row() {
        Text('我的')
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1E293B')
        Blank()
        Button('退出')
          .height(30)
          .fontSize(12)
          .fontColor('#64748B')
          .backgroundColor('#FFFFFF')
          .borderRadius(15)
          .padding({ left: 12, right: 12 })
          .onClick(() => {
            this.isLoggedIn = false;
            this.currentTab = 'home';
            this.userRole = 'user';
            this.loginName = '';
            this.loginAccount = '';
            this.loginPassword = '';
            this.showToast('已退出登录');
          })
      }
      .padding({ left: 20, right: 20, top: 10 })

      // 用户卡片
      Column() {
        Row() {
          Text(this.user.avatarText)
            .width(48)
            .height(48)
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#2563EB')
            .textAlign(TextAlign.Center)
            .backgroundColor('#DBEAFE')
            .borderRadius(24)
          Column() {
            Text(this.user.name)
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
            Text(this.user.verification)
              .fontSize(11)
              .fontColor('#C7D2FE')
              .margin({ top: 4 })
          }
          .margin({ left: 14 })
        }
        .width('100%')
        Row() {
          Text(`可信档案 ${this.user.trustScore} / 100`)
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
            .textAlign(TextAlign.Center)
            .height(20)
            .layoutWeight(this.user.trustScore)
            .backgroundColor('#22C55E')
            .borderRadius(10)
          Text('')
            .height(20)
            .layoutWeight(100 - this.user.trustScore)
            .backgroundColor('#1E293B')
            .borderRadius(10)
        }
        .margin({ top: 16 })
      }
      .width('90%')
      .padding(18)
      .margin({ top: 16 })
      .backgroundColor('#0F172A')
      .borderRadius(18)
      .alignSelf(ItemAlign.Center)

      // 管理员入口卡片
      if (this.userRole === 'admin') {
        Row() {
          Column() {
            Text('管理后台')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor('#7C3AED')
            Text('管理启事、用户和系统数据')
              .fontSize(11)
              .fontColor('#A78BFA')
              .margin({ top: 3 })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          Text('>')
            .fontSize(18)
            .fontColor('#7C3AED')
        }
        .width('90%')
        .padding(16)
        .margin({ top: 12 })
        .backgroundColor('#F5F3FF')
        .borderRadius(14)
        .alignSelf(ItemAlign.Center)
        .onClick(async () => {
          this.currentTab = 'admin';
          await this.loadAdminData();
        })
      }

      // 统计
      Row() {
        this.StatBox(this.user.publishingCount.toString(), '发布中', async () => {
          await this.showMyItems('mine');
        })
        this.StatBox(this.user.recoveredCount.toString(), '已找回', async () => {
          await this.showMyItems('mine');
        })
        this.StatBox(this.user.returnedCount.toString(), '已归还', async () => {
          await this.showMyItems('mine');
        })
      }
      .padding({ left: 20, right: 20, top: 16 })

      Text('效率工具')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1E293B')
        .width('100%')
        .padding({ left: 20, top: 18 })

      Column() {
        this.ToolItem('发', '我的发布', '查看我发布的启事和状态', '#2563EB', async () => {
          this.myItems = await apiService.listItems(this.user.id, '全部', '', '全部', 'me');
          this.myItemsTitle = '我的发布';
          this.currentTab = 'myitems';
        })
        this.ToolItem('藏', '我的收藏', '快速回到关注的线索', '#EF4444', async () => {
          this.myItems = await apiService.listItems(this.user.id, '全部', '', '全部', '', true);
          this.myItemsTitle = '我的收藏';
          this.currentTab = 'myitems';
        })
        this.ToolItem('问', '认领核验问题库', '查看我发布的核验问题', '#22C55E', async () => {
          this.verificationItems = await apiService.listItems(this.user.id, '全部', '', '全部', 'me');
          this.currentTab = 'verification';
        })
        this.ToolItem('站', '附近招领站点', '物业、前台、校园服务台实时更新', '#F59E0B', async () => {
          this.currentTab = 'map';
        })
        if (this.userRole === 'admin') {
          this.ToolItem('管', '管理后台', '管理启事、用户和系统数据', '#7C3AED', async () => {
            this.currentTab = 'admin';
            await this.loadAdminData();
          })
        }
      }
      .padding({ left: 20, right: 20, top: 10 })
    }
  }

  // ==================== 管理员页面 ====================
  @Builder
  AdminPage() {
    Column() {
      this.StatusBar()
      Row() {
        Text('<')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1E293B')
          .onClick(() => {
            this.currentTab = 'profile';
          })
        Text('管理后台')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1E293B')
          .margin({ left: 16 })
        Blank()
        Button('刷新')
          .height(30)
          .fontSize(12)
          .fontColor('#7C3AED')
          .backgroundColor('#F5F3FF')
          .borderRadius(15)
          .padding({ left: 12, right: 12 })
          .onClick(async () => {
            await this.loadAdminData();
            this.showToast('数据已刷新');
          })
      }
      .padding({ left: 20, right: 20, top: 10 })

      // 管理员标签切换
      Row() {
        Text('数据概览')
          .fontSize(13)
          .fontWeight(this.adminTab === 'stats' ? FontWeight.Bold : FontWeight.Normal)
          .fontColor(this.adminTab === 'stats' ? '#7C3AED' : '#64748B')
          .padding({ left: 14, right: 14, top: 6, bottom: 6 })
          .backgroundColor(this.adminTab === 'stats' ? '#F5F3FF' : '#F1F5F9')
          .borderRadius(8)
          .onClick(() => {
            this.adminTab = 'stats';
          })
        Text('启事管理')
          .fontSize(13)
          .fontWeight(this.adminTab === 'items' ? FontWeight.Bold : FontWeight.Normal)
          .fontColor(this.adminTab === 'items' ? '#7C3AED' : '#64748B')
          .padding({ left: 14, right: 14, top: 6, bottom: 6 })
          .backgroundColor(this.adminTab === 'items' ? '#F5F3FF' : '#F1F5F9')
          .borderRadius(8)
          .onClick(() => {
            this.adminTab = 'items';
          })
        Text('用户管理')
          .fontSize(13)
          .fontWeight(this.adminTab === 'users' ? FontWeight.Bold : FontWeight.Normal)
          .fontColor(this.adminTab === 'users' ? '#7C3AED' : '#64748B')
          .padding({ left: 14, right: 14, top: 6, bottom: 6 })
          .backgroundColor(this.adminTab === 'users' ? '#F5F3FF' : '#F1F5F9')
          .borderRadius(8)
          .onClick(() => {
            this.adminTab = 'users';
          })
      }
      .margin({ top: 14, left: 20 })
      .backgroundColor('#F1F5F9')
      .borderRadius(10)
      .padding(3)
      .alignSelf(ItemAlign.Start)

      // 数据概览
      if (this.adminTab === 'stats' && this.adminStats !== undefined) {
        Scroll() {
          Column() {
            Row() {
              this.AdminStatCard('总用户', this.adminStats.totalUsers, '#2563EB')
              this.AdminStatCard('总启事', this.adminStats.totalItems, '#7C3AED')
            }
            Row() {
              this.AdminStatCard('招领中', this.adminStats.foundItems, '#16A34A')
              this.AdminStatCard('寻物中', this.adminStats.lostItems, '#F59E0B')
            }
            Row() {
              this.AdminStatCard('已归还', this.adminStats.returnedItems, '#10B981')
              this.AdminStatCard('待处理', this.adminStats.pendingItems, '#EF4444')
            }
            Row() {
              this.AdminStatCard('总消息', this.adminStats.totalMessages, '#6366F1')
              this.AdminStatCard('未读消息', this.adminStats.unreadMessages, '#EC4899')
            }
          }
          .padding({ left: 20, right: 20, top: 14 })
        }
        .layoutWeight(1)
      }

      // 启事管理
      if (this.adminTab === 'items') {
        List({ space: 10 }) {
          ForEach(this.adminItems, (item: LostFoundItem) => {
            ListItem() {
              Column() {
                Row() {
                  Text(item.category)
                    .width(36)
                    .height(36)
                    .fontSize(11)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(item.type === 'lost' ? '#B45309' : '#2563EB')
                    .textAlign(TextAlign.Center)
                    .backgroundColor(item.type === 'lost' ? '#FFF7ED' : '#EFF6FF')
                    .borderRadius(10)
                  Column() {
                    Text(item.title)
                      .fontSize(13)
                      .fontWeight(FontWeight.Bold)
                      .fontColor('#1E293B')
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                    Text(`${item.status} · ${item.ownerName} · ${item.location}`)
                      .fontSize(10)
                      .fontColor('#94A3B8')
                      .margin({ top: 2 })
                  }
                  .layoutWeight(1)
                  .margin({ left: 10 })
                  Row() {
                    Button('改状态')
                      .height(28)
                      .fontSize(11)
                      .fontColor('#7C3AED')
                      .backgroundColor('#F5F3FF')
                      .borderRadius(14)
                      .padding({ left: 8, right: 8 })
                      .onClick(() => {
                        this.adminEditItemId = this.adminEditItemId === item.id ? 0 : item.id;
                      })
                    Button('删除')
                      .height(28)
                      .fontSize(11)
                      .fontColor('#EF4444')
                      .backgroundColor('#FEF2F2')
                      .borderRadius(14)
                      .padding({ left: 8, right: 8 })
                      .margin({ left: 6 })
                      .onClick(async () => {
                        await this.adminDeleteItem(item.id);
                      })
                  }
                }
                // 状态修改面板
                if (this.adminEditItemId === item.id) {
                  Row() {
                    Button('已招领')
                      .height(26)
                      .fontSize(10)
                      .fontColor('#16A34A')
                      .backgroundColor('#DCFCE7')
                      .borderRadius(13)
                      .padding({ left: 8, right: 8 })
                      .onClick(async () => {
                        await this.adminUpdateItemStatus(item.id, '已招领');
                      })
                    Button('寻物中')
                      .height(26)
                      .fontSize(10)
                      .fontColor('#B45309')
                      .backgroundColor('#FEF3C7')
                      .borderRadius(13)
                      .padding({ left: 8, right: 8 })
                      .margin({ left: 6 })
                      .onClick(async () => {
                        await this.adminUpdateItemStatus(item.id, '寻物中');
                      })
                    Button('认领核验中')
                      .height(26)
                      .fontSize(10)
                      .fontColor('#2563EB')
                      .backgroundColor('#DBEAFE')
                      .borderRadius(13)
                      .padding({ left: 8, right: 8 })
                      .margin({ left: 6 })
                      .onClick(async () => {
                        await this.adminUpdateItemStatus(item.id, '认领核验中');
                      })
                    Button('已归还')
                      .height(26)
                      .fontSize(10)
                      .fontColor('#059669')
                      .backgroundColor('#D1FAE5')
                      .borderRadius(13)
                      .padding({ left: 8, right: 8 })
                      .margin({ left: 6 })
                      .onClick(async () => {
                        await this.adminUpdateItemStatus(item.id, '已归还');
                      })
                  }
                  .margin({ top: 8 })
                }
              }
              .padding(10)
              .backgroundColor('#FFFFFF')
              .borderRadius(12)
            }
          }, (item: LostFoundItem) => `admin-${item.id}`)
        }
        .layoutWeight(1)
        .padding({ left: 20, right: 20, top: 14 })
      }

      // 用户管理
      if (this.adminTab === 'users') {
        List({ space: 10 }) {
          ForEach(this.adminUsers, (u: AdminUser) => {
            ListItem() {
              Column() {
                Row() {
                  Text(u.avatarText)
                    .width(36)
                    .height(36)
                    .fontSize(14)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(u.role === 'admin' ? '#7C3AED' : '#2563EB')
                    .textAlign(TextAlign.Center)
                    .backgroundColor(u.role === 'admin' ? '#F5F3FF' : '#DBEAFE')
                    .borderRadius(10)
                  Column() {
                    Text(u.name)
                      .fontSize(13)
                      .fontWeight(FontWeight.Bold)
                      .fontColor('#1E293B')
                    Text(`${u.account} · ${u.role === 'admin' ? '管理员' : '普通用户'} · 可信度 ${u.trustScore}`)
                      .fontSize(10)
                      .fontColor('#94A3B8')
                      .margin({ top: 2 })
                  }
                  .layoutWeight(1)
                  .margin({ left: 10 })
                  Row() {
                    Text(u.role === 'admin' ? '管理员' : '用户')
                      .fontSize(10)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(u.role === 'admin' ? '#7C3AED' : '#2563EB')
                      .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                      .backgroundColor(u.role === 'admin' ? '#F5F3FF' : '#EFF6FF')
                      .borderRadius(6)
                    Button('管理')
                      .height(26)
                      .fontSize(10)
                      .fontColor('#7C3AED')
                      .backgroundColor('#F5F3FF')
                      .borderRadius(13)
                      .padding({ left: 8, right: 8 })
                      .margin({ left: 6 })
                      .onClick(() => {
                        this.adminEditUserId = this.adminEditUserId === u.id ? 0 : u.id;
                      })
                  }
                }
                // 用户操作面板
                if (this.adminEditUserId === u.id) {
                  Column() {
                    Row() {
                      Text('修改角色：')
                        .fontSize(12)
                        .fontColor('#64748B')
                      Button('设为管理员')
                        .height(26)
                        .fontSize(10)
                        .fontColor('#7C3AED')
                        .backgroundColor('#F5F3FF')
                        .borderRadius(13)
                        .padding({ left: 8, right: 8 })
                        .enabled(u.role !== 'admin')
                        .onClick(async () => {
                          await this.adminUpdateUserRole(u.id, 'admin');
                        })
                      Button('设为普通用户')
                        .height(26)
                        .fontSize(10)
                        .fontColor('#2563EB')
                        .backgroundColor('#EFF6FF')
                        .borderRadius(13)
                        .padding({ left: 8, right: 8 })
                        .margin({ left: 6 })
                        .enabled(u.role !== 'user')
                        .onClick(async () => {
                          await this.adminUpdateUserRole(u.id, 'user');
                        })
                    }
                    .margin({ top: 8 })
                    Row() {
                      Button('删除此用户')
                        .height(26)
                        .fontSize(10)
                        .fontColor('#FFFFFF')
                        .backgroundColor('#EF4444')
                        .borderRadius(13)
                        .padding({ left: 8, right: 8 })
                        .margin({ top: 8 })
                        .enabled(u.role !== 'admin')
                        .onClick(async () => {
                          await this.adminDeleteUser(u.id);
                        })
                      if (u.role === 'admin') {
                        Text('管理员账号不可删除')
                          .fontSize(10)
                          .fontColor('#94A3B8')
                          .margin({ left: 8, top: 8 })
                      }
                    }
                  }
                  .width('100%')
                  .padding(10)
                  .backgroundColor('#F8FAFC')
                  .borderRadius(8)
                  .margin({ top: 8 })
                }
              }
              .padding(10)
              .backgroundColor('#FFFFFF')
              .borderRadius(12)
            }
          }, (u: AdminUser) => `admin-user-${u.id}`)
        }
        .layoutWeight(1)
        .padding({ left: 20, right: 20, top: 14 })
      }
    }
    .height('100%')
  }

  @Builder
  AdminStatCard(label: string, value: number, color: string) {
    Column() {
      Text(value.toString())
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor(color)
      Text(label)
        .fontSize(11)
        .fontColor('#64748B')
        .margin({ top: 4 })
    }
    .layoutWeight(1)
    .height(72)
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#FFFFFF')
    .borderRadius(14)
    .margin({ right: 8, bottom: 8 })
  }

  // ==================== 我的发布/收藏页 ====================
  @Builder
  MyItemsPage() {
    Column() {
      this.StatusBar()
      Row() {
        Text('<')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1E293B')
          .onClick(() => {
            this.currentTab = 'profile';
          })
        Text(this.myItemsTitle)
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1E293B')
          .margin({ left: 16 })
        Blank()
      }
      .padding({ left: 20, right: 20, top: 10 })

      if (this.myItems.length === 0) {
        this.EmptyState('暂无数据', this.myItemsTitle === '我的发布' ? '你还没有发布过启事' : '你还没有收藏过启事')
      } else {
        List({ space: 10 }) {
          ForEach(this.myItems, (item: LostFoundItem) => {
            ListItem() {
              Column() {
                this.ItemCard(item)
                if (this.myItemsTitle === '我的发布' && item.ownerId === this.user.id) {
                  Row() {
                    Button('删除此启事')
                      .height(28)
                      .fontSize(11)
                      .fontColor('#EF4444')
                      .backgroundColor('#FEF2F2')
                      .borderRadius(14)
                      .padding({ left: 12, right: 12 })
                      .margin({ top: 6 })
                      .onClick(async () => {
                        await this.deleteMyItem(item.id);
                        this.myItems = await apiService.listItems(this.user.id, '全部', '', '全部', 'me');
                      })
                  }
                  .width('100%')
                  .justifyContent(FlexAlign.End)
                }
              }
            }
          }, (item: LostFoundItem) => `my-${item.id}`)
        }
        .layoutWeight(1)
        .padding({ left: 20, right: 20, top: 14 })
      }
    }
    .height('100%')
    .backgroundColor('#F1F5F9')
  }

  // ==================== 认领核验问题库页 ====================
  @Builder
  VerificationPage() {
    Column() {
      this.StatusBar()
      Row() {
        Text('<')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1E293B')
          .onClick(() => {
            this.currentTab = 'profile';
          })
        Text('认领核验问题库')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1E293B')
          .margin({ left: 16 })
        Blank()
      }
      .padding({ left: 20, right: 20, top: 10 })

      if (this.verificationItems.length === 0) {
        this.EmptyState('暂无数据', '你还没有发布过启事')
      } else {
        List({ space: 10 }) {
          ForEach(this.verificationItems, (item: LostFoundItem) => {
            ListItem() {
              Column() {
                Row() {
                  Text(item.category)
                    .width(36)
                    .height(36)
                    .fontSize(11)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(item.type === 'lost' ? '#B45309' : '#2563EB')
                    .textAlign(TextAlign.Center)
                    .backgroundColor(item.type === 'lost' ? '#FFF7ED' : '#EFF6FF')
                    .borderRadius(10)
                  Column() {
                    Text(item.title)
                      .fontSize(14)
                      .fontWeight(FontWeight.Bold)
                      .fontColor('#1E293B')
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                    Text(`${item.status} · ${item.location}`)
                      .fontSize(11)
                      .fontColor('#94A3B8')
                      .margin({ top: 2 })
                  }
                  .layoutWeight(1)
                  .margin({ left: 10 })
                }
                // 核验问题详情
                Column() {
                  Text('核验问题')
                    .fontSize(12)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#64748B')
                  Text(item.verificationQuestion)
                    .fontSize(13)
                    .fontColor('#1E293B')
                    .margin({ top: 4 })
                  Text('参考答案')
                    .fontSize(12)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#64748B')
                    .margin({ top: 8 })
                  Text(item.verificationAnswer)
                    .fontSize(13)
                    .fontColor('#16A34A')
                    .margin({ top: 4 })
                }
                .width('100%')
                .padding(10)
                .backgroundColor('#F8FAFC')
                .borderRadius(8)
                .margin({ top: 8 })
              }
              .padding(12)
              .backgroundColor('#FFFFFF')
              .borderRadius(14)
              .onClick(async () => {
                await this.openDetail(item);
              })
            }
          }, (item: LostFoundItem) => `verify-${item.id}`)
        }
        .layoutWeight(1)
        .padding({ left: 20, right: 20, top: 14 })
      }
    }
    .height('100%')
    .backgroundColor('#F1F5F9')
  }

  // ==================== 底部导航栏 ====================
  @Builder
  BottomBar() {
    Row() {
      this.TabButton('首页', 'home')
      this.TabButton('地图', 'map')
      Button('+')
        .width(48)
        .height(48)
        .fontSize(24)
        .fontColor('#FFFFFF')
        .backgroundColor('#2563EB')
        .borderRadius(24)
        .shadow({ radius: 10, color: '#332563EB', offsetY: 4 })
        .onClick(() => {
          this.currentTab = 'publish';
        })
      this.TabButton('消息', 'messages')
      this.TabButton('我的', 'profile')
    }
    .width('100%')
    .height(64)
    .justifyContent(FlexAlign.SpaceAround)
    .backgroundColor('#FFFFFF')
  }

  @Builder
  TabButton(label: string, key: string) {
    Text(label)
      .fontSize(11)
      .fontWeight(this.currentTab === key ? FontWeight.Bold : FontWeight.Normal)
      .fontColor(this.currentTab === key ? '#2563EB' : '#94A3B8')
      .onClick(() => {
        this.currentTab = key;
        if (key === 'messages') {
          apiService.listMessages(this.user.id).then((data: MessageNotice[]) => {
            this.messages = data;
          });
        }
      })
  }

  // ==================== 通用组件 ====================
  @Builder
  Chip(label: string, selected: boolean, action: () => Promise<void>) {
    Button(label)
      .height(28)
      .fontSize(12)
      .fontColor(selected ? '#2563EB' : '#475569')
      .backgroundColor(selected ? '#EFF6FF' : '#FFFFFF')
      .border({ width: selected ? 1 : 0, color: '#2563EB' })
      .borderRadius(14)
      .margin({ right: 8 })
      .onClick(action)
  }

  @Builder
  SourceChip(source: string) {
    Button(source)
      .layoutWeight(1)
      .height(28)
      .fontSize(12)
      .fontColor(this.sourceFilter === source ? '#2563EB' : '#475569')
      .backgroundColor(this.sourceFilter === source ? '#EFF6FF' : '#FFFFFF')
      .borderRadius(14)
      .margin({ right: 6 })
      .onClick(async () => {
        this.sourceFilter = source;
        this.stations = await apiService.listStations(this.sourceFilter);
        this.showToast(`已筛选${source}来源`);
      })
  }

  @Builder
  FixedSubmitButton(key: string, label: string, color: string, action: () => Promise<void>) {
    Button(label)
      .width('100%')
      .height(42)
      .fontSize(14)
      .fontWeight(FontWeight.Bold)
      .fontColor('#FFFFFF')
      .backgroundColor(color)
      .borderRadius(21)
      .shadow({ radius: 8, color: '#332563EB', offsetY: 4 })
      .onClick(action)
  }

  @Builder
  ErrorBanner() {
    Text(this.errorText)
      .width('90%')
      .fontSize(11)
      .fontColor('#B42318')
      .padding(8)
      .backgroundColor('#FEF2F2')
      .borderRadius(8)
      .margin({ top: 6 })
  }

  @Builder
  EmptyState(title: string, desc: string) {
    Column() {
      Text(title)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1E293B')
      Text(desc)
        .fontSize(12)
        .fontColor('#94A3B8')
        .margin({ top: 6 })
    }
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  TextField(label: string, placeholder: string, value: string, onChange: (value: string) => void) {
    Text(label)
      .fontSize(12)
      .fontWeight(FontWeight.Bold)
      .fontColor('#64748B')
      .width('100%')
      .margin({ top: 14 })
    TextInput({ placeholder: placeholder, text: value })
      .height(42)
      .fontSize(14)
      .fontColor('#1E293B')
      .backgroundColor('#F8FAFC')
      .borderRadius(10)
      .margin({ top: 6 })
      .onChange(onChange)
  }

  @Builder
  TextAreaField(label: string, placeholder: string, value: string, onChange: (value: string) => void) {
    Text(label)
      .fontSize(12)
      .fontWeight(FontWeight.Bold)
      .fontColor('#64748B')
      .width('100%')
      .margin({ top: 14 })
    TextArea({ placeholder: placeholder, text: value })
      .height(80)
      .fontSize(14)
      .fontColor('#1E293B')
      .backgroundColor('#F8FAFC')
      .borderRadius(10)
      .margin({ top: 6 })
      .onChange(onChange)
  }

  @Builder
  CategoryPicker() {
    Text('物品分类')
      .fontSize(12)
      .fontWeight(FontWeight.Bold)
      .fontColor('#64748B')
      .width('100%')
      .margin({ top: 14 })
    Flex({ wrap: FlexWrap.Wrap }) {
      ForEach(CATEGORIES, (category: string) => {
        Button(category)
          .height(28)
          .fontSize(11)
          .fontColor(this.formCategory === category ? '#FFFFFF' : '#475569')
          .backgroundColor(this.formCategory === category ? '#2563EB' : '#F1F5F9')
          .borderRadius(14)
          .margin({ right: 6, bottom: 6 })
          .onClick(() => {
            this.formCategory = category;
          })
      })
    }
    .width('100%')
    .margin({ top: 6 })
  }

  @Builder
  StatBox(value: string, label: string, action: () => Promise<void>) {
    Column() {
      Text(value)
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1E293B')
      Text(label)
        .fontSize(11)
        .fontColor('#64748B')
        .margin({ top: 4 })
    }
    .layoutWeight(1)
    .height(68)
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#FFFFFF')
    .borderRadius(14)
    .margin({ right: 8 })
    .onClick(action)
  }

  @Builder
  ToolItem(icon: string, title: string, desc: string, color: string, action: () => Promise<void>) {
    Row() {
      Text(icon)
        .width(34)
        .height(34)
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor(color)
        .textAlign(TextAlign.Center)
        .backgroundColor('#F1F5F9')
        .borderRadius(10)
      Column() {
        Text(title)
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1E293B')
        Text(desc)
          .fontSize(11)
          .fontColor('#94A3B8')
          .margin({ top: 3 })
      }
      .layoutWeight(1)
      .margin({ left: 10 })
      Text('>')
        .fontSize(16)
        .fontColor('#CBD5E1')
    }
    .padding(12)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .margin({ bottom: 8 })
    .onClick(action)
  }
}
