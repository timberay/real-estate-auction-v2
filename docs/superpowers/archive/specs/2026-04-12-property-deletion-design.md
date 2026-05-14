# Property Deletion (Remove from My List) Design

## Summary

Add a delete button to property cards on the properties index page. Clicking it shows a browser confirm dialog warning about data loss. On confirmation, the user's association and all user-scoped analysis data are deleted. The card is removed from the DOM via Turbo Stream.

## Deletion Scope

Per-user removal only. The Property record itself is preserved for other users.

| Target | Model | Condition |
|--------|-------|-----------|
| User-property link | `UserProperty` | `user_id + property_id` |
| Inspection results | `InspectionResult` | `user_id + property_id` |
| Rights analysis report | `RightsAnalysisReport` | `user_id + property_id` |
| LLM analysis logs | `LlmAnalysisLog` | `user_id + property_id` |

Not deleted: `Property`, `AuctionSchedule`, `ActiveStorage::Attachment` (documents).

## Route

Add `:destroy` to `resources :properties, only: [:index, :show, :create, :destroy]`.

## Controller — `PropertiesController#destroy`

1. Find `current_user.user_properties.find_by!(property_id: params[:id])` for authorization.
2. Within a transaction, delete:
   - `InspectionResult.where(user: current_user, property: property)`
   - `RightsAnalysisReport.where(user: current_user, property: property)`
   - `LlmAnalysisLog.where(user: current_user, property: property)`
   - The `UserProperty` record
3. Respond with `turbo_stream.remove(dom_id)` format.
4. HTML fallback: `redirect_to properties_path` with flash notice.

## UI — PropertyCardComponent

Add a delete `button_to` at the bottom of each card with:
- `method: :delete`
- `data-turbo-confirm` with message: "이 물건을 내 목록에서 삭제합니다. 저장된 분석 결과, 권리분석 보고서 등 모든 관련 데이터가 함께 삭제되며 복구할 수 없습니다. 삭제하시겠습니까?"
- Trash icon + "삭제" label, styled as a subtle danger button (text-red, no fill)

Each card needs a stable DOM id (`dom_id(@user_property)` or `dom_id(@property)`) for Turbo Stream targeting.

## Confirm Message

> 이 물건을 내 목록에서 삭제합니다. 저장된 분석 결과, 권리분석 보고서 등 모든 관련 데이터가 함께 삭제되며 복구할 수 없습니다. 삭제하시겠습니까?

## Testing

- Controller test: verify destroy removes UserProperty + scoped records, preserves Property.
- Controller test: verify user cannot delete another user's property association.
- Controller test: verify Turbo Stream response format.
