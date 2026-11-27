# Admin editor setup

The content editor at `#admin` signs in with **Supabase Auth**. Visitors can
read `site_content`; only users listed in `site_admins` can change it. This is
enforced by row-level security in the database
(`supabase/migrations/20261127000000_secure_site_content.sql`), not by the page.

Nothing secret belongs in `index.html`. The Supabase URL and anon/publishable
key in it are public by design.

## One-time setup

1. **Apply the migration.** Supabase dashboard → SQL Editor → paste the
   migration file → Run. It removes the old `x-admin-secret` write policy and
   adds the new ones. It is safe to run again.
2. **Turn off public sign-ups.** Authentication → Sign In / Providers →
   disable "Allow new users to sign up". (Sign-ups would not grant edit
   rights anyway, but there is no reason to allow them.)
3. **Create the admin user.** Authentication → Users → Add user → Create new
   user, with the admin's email and a strong new password, and tick
   "Auto Confirm User".
4. **Make that user an admin.** In the SQL Editor:

   ```sql
   insert into public.site_admins (user_id)
   select id from auth.users where email = 'admin@example.com';
   ```

5. Open `/#admin`, sign in with that email and password, and save a small
   edit to confirm it works.

## Adding or removing an admin

Add: repeat steps 3 and 4. Remove:

```sql
delete from public.site_admins
where user_id = (select id from auth.users where email = 'admin@example.com');
```
