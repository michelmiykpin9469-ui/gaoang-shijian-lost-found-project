import { http } from '@kit.NetworkKit';
import {
  AdminStats,
  AdminUser,
  ClaimRequest,
  ContactResult,
  DeleteResult,
  FavoriteResult,
  LoginResult,
  LostFoundItem,
  MapStation,
  MessageNotice,
  NewLostFoundItem,
  UploadResult,
  UserProfile
} from '../model/LostFoundItem';

export const API_BASE_URL: string = 'http://192.168.1.10:3000/api';

class LoginPayload {
	name: string;
  username: string;
  password: string;
  role: string;

  constructor(name: string, username: string, password: string, role: string) {
this.name = name;
    this.username = username;
    this.password = password;
    this.role = role;
  }
}

interface ParsedError {
  message?: string;
}

interface StatusPayload {
  userId: number;
  status: string;
}

interface ClaimPayload {
  userId: number;
  answer: string;
  note: string;
}

interface UserPayload {
  userId: number;
}

interface RolePayload {
  userId: number;
  role: string;
}

interface UploadPayload {
  fileName: string;
  mimeType: string;
  base64: string;
}

class ApiService {
  async login(name: string, account: string, password: string, role: string): Promise<LoginResult> {
  const apiRole: string = role === 'admin' || role === '管理员' ? 'admin' : 'user';
  const payload: LoginPayload = new LoginPayload(name, account, password, apiRole);

  return await this.requestJson<LoginResult>(`${API_BASE_URL}/login`, http.RequestMethod.POST, payload);
}
  async listItems(userId: number, filter: string, keyword: string = '', status: string = '全部', owner: string = '', favorite: boolean = false): Promise<LostFoundItem[]> {
    const queryType = this.itemFilterToQuery(filter);
    const url = `${API_BASE_URL}/items?userId=${userId}&type=${encodeURIComponent(queryType)}&keyword=${encodeURIComponent(keyword)}&status=${encodeURIComponent(status)}&owner=${encodeURIComponent(owner)}&favorite=${favorite ? '1' : ''}`;
    return await this.getJson<LostFoundItem[]>(url);
  }

  async getItem(userId: number, id: number): Promise<LostFoundItem> {
    return await this.getJson<LostFoundItem>(`${API_BASE_URL}/items/${id}?userId=${userId}`);
  }

  async createItem(item: NewLostFoundItem): Promise<LostFoundItem> {
    return await this.requestJson<LostFoundItem>(`${API_BASE_URL}/items`, http.RequestMethod.POST, item);
  }

  async uploadImage(fileName: string, mimeType: string, base64: string): Promise<UploadResult> {
    const payload: UploadPayload = { fileName: fileName, mimeType: mimeType, base64: base64 };
    return await this.requestJson<UploadResult>(`${API_BASE_URL}/uploads`, http.RequestMethod.POST, payload);
  }

  async updateStatus(userId: number, id: number, status: string): Promise<LostFoundItem> {
    const payload: StatusPayload = { userId: userId, status: status };
    return await this.requestJson<LostFoundItem>(`${API_BASE_URL}/items/${id}/status`, http.RequestMethod.POST, payload);
  }

  async contactPublisher(userId: number, id: number): Promise<ContactResult> {
    const payload: UserPayload = { userId: userId };
    return await this.requestJson<ContactResult>(`${API_BASE_URL}/items/${id}/contact`, http.RequestMethod.POST, payload);
  }

  async submitClaim(userId: number, id: number, answer: string, note: string): Promise<ClaimRequest> {
    const payload: ClaimPayload = { userId: userId, answer: answer, note: note };
    return await this.requestJson<ClaimRequest>(`${API_BASE_URL}/items/${id}/claim`, http.RequestMethod.POST, payload);
  }

  async completeReturn(userId: number, id: number): Promise<LostFoundItem> {
    const payload: UserPayload = { userId: userId };
    return await this.requestJson<LostFoundItem>(`${API_BASE_URL}/items/${id}/return`, http.RequestMethod.POST, payload);
  }

  async toggleFavorite(userId: number, id: number): Promise<FavoriteResult> {
    const payload: UserPayload = { userId: userId };
    return await this.requestJson<FavoriteResult>(`${API_BASE_URL}/items/${id}/favorite`, http.RequestMethod.POST, payload);
  }

  async listStations(source: string): Promise<MapStation[]> {
    return await this.getJson<MapStation[]>(`${API_BASE_URL}/stations?source=${encodeURIComponent(source)}`);
  }

  async getProfile(userId: number): Promise<UserProfile> {
    return await this.getJson<UserProfile>(`${API_BASE_URL}/profile?userId=${userId}`);
  }

  async listMessages(userId: number): Promise<MessageNotice[]> {
    return await this.getJson<MessageNotice[]>(`${API_BASE_URL}/messages?userId=${userId}`);
  }

  async markMessageRead(userId: number, id: number): Promise<MessageNotice> {
    const payload: UserPayload = { userId: userId };
    return await this.requestJson<MessageNotice>(`${API_BASE_URL}/messages/${id}/read`, http.RequestMethod.POST, payload);
  }

  // 管理员接口
  async adminGetStats(userId: number): Promise<AdminStats> {
    return await this.getJson<AdminStats>(`${API_BASE_URL}/admin/stats?userId=${userId}`);
  }

  async adminGetUsers(userId: number): Promise<AdminUser[]> {
    return await this.getJson<AdminUser[]>(`${API_BASE_URL}/admin/users?userId=${userId}`);
  }

  async adminGetItems(userId: number): Promise<LostFoundItem[]> {
    return await this.getJson<LostFoundItem[]>(`${API_BASE_URL}/admin/items?userId=${userId}`);
  }

  async adminDeleteItem(userId: number, itemId: number): Promise<void> {
    await this.requestJson<DeleteResult>(`${API_BASE_URL}/admin/items/${itemId}?userId=${userId}`, http.RequestMethod.DELETE);
  }

  async deleteMyItem(userId: number, itemId: number): Promise<void> {
    await this.requestJson<DeleteResult>(`${API_BASE_URL}/items/${itemId}?userId=${userId}`, http.RequestMethod.DELETE);
  }

  async adminDeleteUser(userId: number, targetUserId: number): Promise<void> {
    await this.requestJson<DeleteResult>(`${API_BASE_URL}/admin/users/${targetUserId}?userId=${userId}`, http.RequestMethod.DELETE);
  }

  async adminUpdateUserRole(userId: number, targetUserId: number, role: string): Promise<AdminUser> {
    const payload: RolePayload = { userId: userId, role: role };
    return await this.requestJson<AdminUser>(`${API_BASE_URL}/admin/users/${targetUserId}/role`, http.RequestMethod.PUT, payload);
  }

  private async getJson<T>(url: string): Promise<T> {
    return await this.requestJson<T>(url, http.RequestMethod.GET);
  }

  private async requestJson<T>(url: string, method: http.RequestMethod, body?: Object): Promise<T> {
    const request = http.createHttp();

    try {
      const httpResponse: http.HttpResponse = await request.request(url, {
        method: method,
        header: {
          'Content-Type': 'application/json'
        },
        readTimeout: 6000,
        connectTimeout: 6000,
        extraData: body === undefined ? undefined : JSON.stringify(body)
      });

      if (httpResponse.responseCode < 200 || httpResponse.responseCode >= 300) {
        const errorBody: string = String(httpResponse.result || '');
        let errorMessage: string = `HTTP ${httpResponse.responseCode}`;

        try {
          const parsed: ParsedError = JSON.parse(errorBody);
          if (parsed.message) {
            errorMessage = parsed.message;
          }
        } catch {
          // ignore
        }

        throw new Error(errorMessage);
      }

      const result: T = JSON.parse(String(httpResponse.result));
      return result;
    } catch (err) {
      if (err instanceof Error) {
        throw err;
      }

      throw new Error(String(err));
    } finally {
      request.destroy();
    }
  }

  private itemFilterToQuery(filter: string): string {
    if (filter === '招领') {
      return 'found';
    }

    if (filter === '寻物') {
      return 'lost';
    }

    if (filter === '全部') {
      return 'all';
    }

    return '';
  }
}

export const apiService = new ApiService();