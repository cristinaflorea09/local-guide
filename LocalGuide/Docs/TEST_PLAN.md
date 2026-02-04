# LocalGuide Test Plan

## Purpose
Validate core user flows, safety/UGC controls, payments visibility, and performance for staging before release.

## Environments
- Staging Firebase project with `GoogleService-Info-Staging.plist` bundled in the app target.
- iOS simulator targets: iPhone 15, iPhone SE (3rd gen), iPad 10th gen, iPad Pro 12.9".
- iOS device targets: one recent iPhone and one iPad for final smoke.

## Test Data
- Use new traveler accounts per run (unique email).
- Use existing guide/host accounts in staging to validate seller flows.
- Seed at least 10 tours and 10 experiences in staging for list, map, and detail validation.

## Manual Functional Tests
Auth and onboarding:
1. Create traveler account, accept terms, verify post-login state.
2. Login with email/password, Apple, Google.
3. Logout and login again.
4. Password reset flow.

Account:
1. Open Account view and verify profile data.
2. Open Community Guidelines and Privacy Policy link.
3. Blocked users list shows and unblocks.
4. Delete account with reauth, data removed, session cleared.

Community:
1. Create post with title/body/city.
2. View post detail, add comment, like comment.
3. Edit and delete own comment.
4. Report post and comment in-app.
5. Report post and comment by email includes IDs.
6. Block user from feed card and verify hidden content.

Experiences and tours:
1. List views load within 1 second with pagination enabled.
2. Open detail view and verify data refresh after edit.
3. Create and edit experience/tour and confirm detail view updates.
4. Verify image loading and caching.

Maps:
1. Map loads tours and experiences within 1 second at default zoom.
2. Pan and zoom updates data without blocking UI.
3. Marker detail opens correct detail view.

Payments and subscriptions:
1. Premium paywall displays correctly for non-premium.
2. Purchase and restore flow in staging (if configured).
3. Seller plans and Stripe onboarding visible for guide/host.

Notifications:
1. Notifications registration does not block UI.
2. In-app updates do not show visible refresh spinners on list views.

iPad and layout:
1. All primary tabs render without clipped text.
2. Account view is scrollable and toolbar does not overlap title.
3. Community composer and detail views are usable in split screen.

## Automated UI Tests (XCUITest)
Suite: `LocalGuideUITests`
- Traveler flow: register in staging, open Community, create post, add/like/edit/delete comment.
- Host flow: register in staging, create experience, edit experience title, verify detail refresh.
- Guide flow: register in staging, create tour, edit tour title, verify detail refresh.

## Performance Targets
- Initial list content visible in under 1 second for Tours and Experiences.
- Map data visible within 1 second at default zoom.
- Image thumbnails visible within 1 second on cached loads.

## Acceptance Criteria
- All functional tests pass in staging without crashes.
- UI tests pass on simulator in staging.
- No critical layout regressions on iPad and small iPhone.
- No blocking performance regressions on list and map views.
