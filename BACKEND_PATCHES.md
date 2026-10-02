# Backend changes the app needs (found while reading the repo)

## 1. api-gateway: WebSocket route order bug  (REQUIRED for chat)
`notification-service` route matches `/ws/**` and is listed BEFORE chat-service, so `/ws/chat` is
routed to notification-service and the chat handshake fails. Narrow it:

```yaml
- id: notification-service
  uri: lb://NOTIFICATION-SERVICE
  predicates:
    - Path=/api/notifications/**, /ws/notifications/**
```
Also let Google OAuth pass through the gateway:
```yaml
- id: auth-service
  uri: lb://AUTH-SERVICE
  predicates:
    - Path=/api/auth/**, /oauth2/**, /login/oauth2/**
```

## 2. Google login for mobile
- Set `FRONTEND_URL=worknear://auth` for auth-service. Existing OAuth2LoginSuccessHandler then redirects to
  `worknear://auth/select-role?token=...` or `worknear://auth/oauth-success?token=...&refreshToken=...` - the app handles both.
- Google Cloud console -> authorized redirect URI: `<API_BASE>/login/oauth2/code/google`.
- JwtAuthGatewayFilter OPEN_PATHS already allows /oauth2 and /login.

## 3. FCM push when the WebSocket is closed
pom (notification-service): `com.google.firebase:firebase-admin:9.3.0` (+ spring-boot-starter-data-jpa if it has no DB).

```java
@Entity @Table(name="device_tokens", uniqueConstraints=@UniqueConstraint(columnNames={"token"}))
@Getter @Setter public class DeviceToken {
  @Id @GeneratedValue(strategy=GenerationType.IDENTITY) private Long id;
  private Long userId;
  @Column(nullable=false, length=400) private String token;
}
public interface DeviceTokenRepository extends JpaRepository<DeviceToken, Long> {
  List<DeviceToken> findByUserId(Long userId);
  Optional<DeviceToken> findByToken(String token);
}

@RestController @RequestMapping("/api/notifications") @RequiredArgsConstructor
public class DeviceTokenController {
  private final DeviceTokenRepository repo;
  @PostMapping("/device-token")
  public void register(@RequestHeader("X-User-Id") Long userId, @RequestBody Map<String,String> body) {
    DeviceToken d = repo.findByToken(body.get("token")).orElseGet(DeviceToken::new);
    d.setUserId(userId); d.setToken(body.get("token")); repo.save(d);   // token may move between accounts
  }
}

@Service @Slf4j
public class FcmService {
  private final DeviceTokenRepository repo;
  public FcmService(DeviceTokenRepository repo, @Value("${firebase.credentials-path}") String path) throws IOException {
    this.repo = repo;
    if (FirebaseApp.getApps().isEmpty())
      FirebaseApp.initializeApp(FirebaseOptions.builder()
          .setCredentials(GoogleCredentials.fromStream(new FileInputStream(path))).build());
  }
  public void sendToUser(String userId, String title, String body, Map<String,String> data) {
    for (DeviceToken t : repo.findByUserId(Long.valueOf(userId))) {
      try {
        FirebaseMessaging.getInstance().send(Message.builder().setToken(t.getToken())
            .setNotification(Notification.builder().setTitle(title).setBody(body).build())
            .putAllData(data).build());
      } catch (FirebaseMessagingException e) {
        if (e.getMessagingErrorCode() == MessagingErrorCode.UNREGISTERED) repo.delete(t);
        else log.warn("FCM failed for user {}", userId, e);
      }
    }
  }
}
```
PushService: replace the TODO branch
```java
if (session == null || !session.isOpen()) {
  fcm.sendToUser(userId, "WorkNear", "New job near you", Map.of("payload", payloadJson));
  return;
}
```
Keep the Firebase service-account JSON OUT of git; mount it as a docker secret/volume.

## 4. Security issues spotted (fix before launch)
| # | Where | Problem | Fix |
|---|---|---|---|
| 1 | chat + notification WS handlers | userId comes from the client's query string, so any logged-in user can open someone else's socket | read `X-User-Id` from `session.getHandshakeHeaders()` (gateway already injects it) |
| 2 | ChatHistoryController | no participant check (your TODO) | compare X-User-Id with job.customerId / acceptedLabourId |
| 3 | PaymentController.createOrder | trusts customerId/labourId/amount from the body | take customer from X-User-Id; load labour + amount from the job |
| 4 | Razorpay webhook | reads flat `order_id`/`payment_id`; real payload is `payload.payment.entity.*`, so the wallet is probably never credited | parse the nested entity (your own TODO) |
| 5 | GET /wallet/{labourId} | any user can read any wallet | use X-User-Id |
| 6 | media-service kyc-docs | Aadhaar/PAN images in S3 | private bucket + presigned URLs, never public |

## 5. Missing endpoints (app works around them)
- No way to set a job COMPLETED/IN_PROGRESS (status enum exists, no controller method).
- No "jobs accepted by me" for labour - the app can only open a job right after accepting it. Add `GET /api/jobs/accepted`.
- Notification payload only has jobId, so the app does one GET /api/jobs/{id} per offer (fine, but adding title/budget saves a call).
- POST /api/kyc/documents hits a unique (labourId, docType) constraint on re-upload after rejection - make it upsert.
