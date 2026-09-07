retail-management-app/
│
├── README.md
├── .gitignore
├── .env.example
├── docker-compose.yml
│
├── docs/                              # Tài liệu toàn bộ dự án
│   ├── requirements/
│   │   ├── SRS.md
│   │   ├── use-case.md
│   │   └── business-rules.md
│   │
│   ├── architecture/
│   │   ├── system-architecture.md
│   │   ├── mobile-architecture.md
│   │   ├── backend-architecture.md
│   │   └── database-architecture.md
│   │
│   ├── database/
│   │   ├── ERD.md
│   │   └── database-schema.sql
│   │
│   ├── api/
│   │   └── API.md
│   │
│   └── testing/
│       ├── test-plan.md
│       ├── test-cases.md
│       ├── bug-report.md
│       └── test-report.md
│
├── mobile/                            # ================= FLUTTER =================
│   │
│   ├── android/
│   ├── ios/
│   ├── web/
│   │
│   ├── assets/
│   │   ├── images/
│   │   ├── icons/
│   │   └── fonts/
│   │
│   ├── lib/
│   │   ├── main.dart
│   │   ├── app.dart
│   │   │
│   │   ├── core/                     # Thành phần dùng chung
│   │   │   ├── constants/
│   │   │   ├── config/
│   │   │   ├── network/
│   │   │   ├── storage/
│   │   │   ├── router/
│   │   │   ├── theme/
│   │   │   ├── utils/
│   │   │   └── errors/
│   │   │
│   │   ├── shared/                   # Widget dùng chung
│   │   │   ├── widgets/
│   │   │   ├── components/
│   │   │   └── models/
│   │   │
│   │   └── features/                 # Các chức năng của app
│   │       │
│   │       ├── auth/
│   │       │   ├── data/
│   │       │   │   ├── datasources/
│   │       │   │   ├── models/
│   │       │   │   └── repositories/
│   │       │   ├── domain/
│   │       │   │   ├── entities/
│   │       │   │   ├── repositories/
│   │       │   │   └── usecases/
│   │       │   └── presentation/
│   │       │       ├── pages/
│   │       │       ├── widgets/
│   │       │       └── controllers/
│   │       │
│   │       ├── dashboard/
│   │       ├── employees/
│   │       ├── departments/
│   │       ├── shifts/
│   │       ├── schedules/
│   │       ├── attendance/
│   │       ├── leave/
│   │       ├── notifications/
│   │       └── profile/
│   │
│   ├── test/
│   │   ├── core/
│   │   └── features/
│   │
│   ├── pubspec.yaml
│   └── analysis_options.yaml
│
├── backend/                           # ================= NODE.JS =================
│   │
│   ├── src/
│   │   ├── main.ts
│   │   ├── app.module.ts
│   │   │
│   │   ├── config/
│   │   │   ├── app.config.ts
│   │   │   └── database.config.ts
│   │   │
│   │   ├── common/                   # Thành phần dùng chung
│   │   │   ├── guards/
│   │   │   ├── interceptors/
│   │   │   ├── filters/
│   │   │   ├── decorators/
│   │   │   └── pipes/
│   │   │
│   │   ├── database/
│   │   │   ├── prisma.service.ts
│   │   │   └── seed/
│   │   │
│   │   └── modules/                  # Các module Backend
│   │       │
│   │       ├── auth/
│   │       │   ├── auth.controller.ts
│   │       │   ├── auth.service.ts
│   │       │   ├── auth.module.ts
│   │       │   ├── dto/
│   │       │   └── guards/
│   │       │
│   │       ├── employees/
│   │       │   ├── employees.controller.ts
│   │       │   ├── employees.service.ts
│   │       │   ├── employees.module.ts
│   │       │   ├── dto/
│   │       │   └── entities/
│   │       │
│   │       ├── departments/
│   │       ├── shifts/
│   │       ├── schedules/
│   │       ├── attendance/
│   │       ├── leave/
│   │       ├── notifications/
│   │       └── dashboard/
│   │
│   ├── test/
│   │   ├── unit/
│   │   └── integration/
│   │
│   ├── package.json
│   ├── tsconfig.json
│   └── Dockerfile
│
├── database/                          # ================= DATABASE =================
│   │
│   ├── migrations/
│   ├── seeds/
│   ├── functions/
│   └── schema.sql
│
├── deployment/                        # ================= DEPLOYMENT =================
│   │
│   ├── Dockerfile
│   ├── docker-compose.yml
│   ├── nginx/
│   └── scripts/
│       ├── deploy.sh
│       ├── backup.sh
│       └── restore.sh
│
└── .github/                           # ================= CI/CD =================
    │
    └── workflows/
        ├── mobile.yml
        ├── backend.yml
        ├── database.yml
        └── deploy.yml



                            RETAIL MANAGEMENT APP
                           │
             ┌─────────────┴─────────────┐
             │                           │
             ▼                           ▼
      ┌─────────────┐             ┌─────────────┐
      │   FLUTTER   │             │   NODE.JS   │
      │   MOBILE    │◄── HTTPS ──►│   BACKEND   │
      └─────────────┘             └──────┬──────┘
                                         │
                                      Prisma
                                         │
                                         ▼
                                ┌─────────────────┐
                                │   PostgreSQL    │
                                └─────────────────┘

