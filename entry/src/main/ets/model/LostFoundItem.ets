export interface LostFoundItem {
  id: number;
  ownerId: number;
  type: string;
  status: string;
  title: string;
  category: string;
  source: string;
  location: string;
  distance: string;
  eventTime: string;
  description: string;
  contactName: string;
  contactPhone: string;
  privacyNote: string;
  verificationQuestion: string;
  verificationAnswer: string;
  score: number;
  scoreLabel: string;
  iconText: string;
  imageUrl: string;
  color: string;
  createdAt: number;
  updatedAt: number;
  ownerName: string;
  ownerVerification: string;
  favorite: number;
  claimRequestId: number;
  claimStatus: string;
  claimAnswer: string;
}

export interface NewLostFoundItem {
  userId: number;
  type: string;
  title: string;
  category: string;
  source: string;
  location: string;
  distance: string;
  eventTime: string;
  description: string;
  contactName: string;
  contactPhone: string;
  privacyNote: string;
  verificationQuestion: string;
  verificationAnswer: string;
  imageUrl: string;
}

export interface UserProfile {
  id: number;
  name: string;
  account: string;
  password: string;
  role: string;
  avatarText: string;
  verification: string;
  trustScore: number;
  publishingCount: number;
  recoveredCount: number;
  returnedCount: number;
  createdAt: number;
}

export interface LoginResult {
  token: string;
  user: UserProfile;
}

export interface MapStation {
  id: number;
  name: string;
  source: string;
  itemId: number;
  itemTitle: string;
  timeText: string;
  distance: string;
  statusText: string;
  mapX: number;
  mapY: number;
  color: string;
}

export interface MessageNotice {
  id: number;
  userId: number;
  itemId: number;
  type: string;
  title: string;
  content: string;
  timeText: string;
  unread: number;
  createdAt: number;
}

export interface ClaimRequest {
  id: number;
  itemId: number;
  claimantId: number;
  answer: string;
  note: string;
  status: string;
  createdAt: number;
  updatedAt: number;
}

export interface ContactResult {
  contactName: string;
  contactPhone: string;
  message: string;
}

export interface FavoriteResult {
  favorite: number;
  message: string;
}

export interface UploadResult {
  fileName: string;
  imageUrl: string;
}

export interface AdminStats {
  totalUsers: number;
  totalItems: number;
  foundItems: number;
  lostItems: number;
  returnedItems: number;
  pendingItems: number;
  totalMessages: number;
  unreadMessages: number;
}

export interface AdminUser {
  id: number;
  name: string;
  account: string;
  role: string;
  avatarText: string;
  verification: string;
  trustScore: number;
  publishingCount: number;
  recoveredCount: number;
  returnedCount: number;
  createdAt: number;
}

export interface DeleteResult {
  message: string;
}

export const CATEGORY_FILTERS: string[] = ['全部', '招领', '寻物', '证件', '数码'];
export const SOURCE_FILTERS: string[] = ['全部', '教学楼', '图书馆', '运动区', '其他'];
export const STATUS_FILTERS: string[] = ['全部', '已招领', '认领核验中', '已归还', '寻物中', '已找回'];
export const CATEGORIES: string[] = ['证件', '数码', '日用品', '钥匙', '书籍', '其他'];
