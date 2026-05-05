# Property Favorite (즐겨찾기) — Design

**Date:** 2026-05-05
**Status:** Approved
**Scope:** "내 물건" 목록에 즐겨찾기 토글 + 정렬 우선순위

## Goal

사용자가 "내 물건" 카드의 별 아이콘을 토글해 특정 물건을 즐겨찾기로 표시하면, 다음 페이지 진입 시 해당 물건들이 목록 상단에 먼저 표시된다.

## User Scenario

1. `/properties` 접속 → 내 물건 카드 목록이 표시된다 (현재: 추가한 순서).
2. 카드 하단 "삭제" 버튼 우측의 빈 별 아이콘을 클릭한다.
3. 별 아이콘이 **즉시** 꽉 찬 노란색 별로 바뀐다 (페이지 위치는 그대로).
4. 페이지를 새로고침하거나 다른 페이지에서 다시 진입하면, 해당 카드가 목록 상단에 표시된다.
5. 다시 클릭하면 빈 별로 돌아오고, 다음 진입 시 원래 순서대로 정렬된다.

## Non-Goals

- 토글 즉시 카드를 위로 재배치하지 않는다 (UX는 새로고침 시점에 반영).
- 즐겨찾기 카운트, 즐겨찾기 전용 필터 탭, 즐겨찾기 알림 등은 포함하지 않는다.
- 검색 결과 페이지에는 별 아이콘을 추가하지 않는다 (`PropertyCardComponent`는 `properties#index`에서만 사용됨).

## Data Model

### Migration

```ruby
class AddFavoriteToUserProperties < ActiveRecord::Migration[8.0]
  def change
    add_column :user_properties, :favorite, :boolean, default: false, null: false
    add_index :user_properties, [:user_id, :favorite, :created_at],
              order: { favorite: :desc, created_at: :desc },
              name: "index_user_properties_on_user_favorite_created"
  end
end
```

### Model — `UserProperty`

```ruby
scope :ordered_for_list, -> { order(favorite: :desc, created_at: :desc) }
```

## Routes

```ruby
resources :properties, only: [...] do
  member do
    patch :toggle_favorite
  end
end
```

→ `PATCH /properties/:id/toggle_favorite`

## Controller — `PropertiesController`

```ruby
def toggle_favorite
  user_property = current_user.user_properties.find_by!(property_id: params[:id])
  user_property.update!(favorite: !user_property.favorite)

  respond_to do |format|
    format.turbo_stream do
      render turbo_stream: turbo_stream.replace(
        helpers.dom_id(user_property, :favorite_toggle),
        FavoriteToggleComponent.new(user_property: user_property)
      )
    end
    format.html { redirect_to properties_path }
  end
end
```

`index` action의 정렬을 `.order(created_at: :desc)` → `.ordered_for_list` 로 교체.

## View

### `PropertyCardComponent`

- `initialize`에 `user_property: nil` 키워드 인자 추가 (기존 `property:`, `safety_rating:`, `max_bid_amount:`, `analyzed:`는 그대로 유지 — surgical change).
- 호출부에서 `user_property: up`을 넘긴다.
- "삭제" 버튼이 있는 마지막 영역의 레이아웃을 `flex items-center justify-between` 으로 변경:
  - 좌측: 기존 "삭제" 버튼
  - 우측: `user_property.present?`일 때만 `<%= render FavoriteToggleComponent.new(user_property: @user_property) %>` 렌더링 (방어적 — 미래에 검색 결과 등에서 재사용될 가능성 대비).

### Favorite toggle 부분 분리

UI 단위와 Turbo Stream 교체 단위가 같으므로 작은 ViewComponent로 분리한다.

**`FavoriteToggleComponent`** (`app/components/favorite_toggle_component.rb` + `.html.erb`):

- `initialize(user_property:)`
- `dom_id(user_property, :favorite_toggle)` 으로 wrapping DOM id 부여
- `button_to toggle_favorite_property_path(user_property.property), method: :patch, ...`
- 별 아이콘 인라인 SVG 두 가지:
  - `favorite=false`: outline star, `text-slate-400 hover:text-amber-400`
  - `favorite=true`: solid star, `text-amber-400`
- 접근성: `aria-label="즐겨찾기 추가"` / `"즐겨찾기 해제"` (상태에 따라), `aria-pressed`

### `properties/index.html.erb` 호출부

기존:

```erb
<%= render PropertyCardComponent.new(
  property: up.property,
  safety_rating: up.safety_rating,
  max_bid_amount: ...,
  analyzed: ...
) %>
```

→ `user_property: up` 키워드 추가.

## Testing (TDD 순서)

작성 순서대로 빨간색 → 초록색 사이클을 돈다.

1. **Model spec** — `UserProperty.ordered_for_list`
   - favorite=true가 favorite=false보다 먼저
   - 같은 favorite 그룹 내에서는 created_at desc

2. **Request spec** — `PATCH /properties/:id/toggle_favorite`
   - 비로그인: redirect
   - 다른 유저의 property_id: 404
   - 정상: favorite 토글 + Turbo Stream 응답에 새 별 아이콘 포함

3. **Component spec** — `FavoriteToggleComponent`
   - `favorite=false` 렌더링 시 outline star + `aria-label="즐겨찾기 추가"`
   - `favorite=true` 렌더링 시 solid star + `aria-label="즐겨찾기 해제"`

4. **Controller index spec 보강** — favorite=true인 user_property가 favorite=false인 user_property보다 먼저 노출되는지 (이미 created_at 정렬을 검증하는 spec이 있다면 그것을 보강).

## Out of Scope (확인된 비포함)

- 즐겨찾기 즉시 재정렬 애니메이션
- 즐겨찾기 일괄 해제
- 즐겨찾기를 다른 모델/페이지로 확장

## Tidy First 분리 권고

다음 두 commit 그룹으로 나눈다:

**구조 변경 (refactor) commit:**
- `PropertyCardComponent`의 마지막 영역 레이아웃을 `flex justify-between`으로 변경 (현재 삭제 버튼만 있어도 시각적으로 동일)

**행동 변경 (feature) commits (각 테스트 단위로):**
- 마이그레이션 + `ordered_for_list` scope + model spec
- `toggle_favorite` 라우트 + 컨트롤러 + request spec
- `FavoriteToggleComponent` + component spec
- `PropertyCardComponent`에 toggle 끼워 넣기 + index 정렬 교체

## Korean UX Copy

- aria-label: "즐겨찾기 추가" / "즐겨찾기 해제"
- 토글 후 toast 등은 표시하지 않는다 (즉시 별 아이콘 변경으로 충분).
