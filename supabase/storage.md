# Storage setup

Create bucket `avatars` in Supabase Storage:
- Public bucket: enabled
- File size limit: 2 MB
- Allowed MIME types: `image/jpeg`, `image/png`, `image/webp`

Policies (or use `supabase/mvp.sql` which creates them if storage schema exists):
- Allow anon and authenticated users to read objects in `avatars`
- Allow anon users to upload to `avatars` (signup photo upload)

Example policy:
```sql
create policy "avatars_read" on storage.objects for select to anon, authenticated using (bucket_id = 'avatars');
create policy "avatars_insert_anon" on storage.objects for insert to anon with check (bucket_id = 'avatars');
```
