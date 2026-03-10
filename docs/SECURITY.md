# DingDong Security Checklist

> Full security requirements defined in PRD.md Section 9.
> This file will be expanded during Phase 3.

## Pre-commit checklist
- [ ] No .env files committed
- [ ] No serviceAccount*.json committed  
- [ ] No device_secret values committed
- [ ] GitHub secret scanning enabled
```

---

## Your Order of Operations Right Now

1. Run the folder scaffold commands above
2. Add starter content to API.md and SECURITY.md
3. Place `google-services.json` in `mobile/android/app/`
4. Commit everything:
```
git add .
git commit -m "Add repo scaffold, docs stubs, firmware and cloud structure"
git push