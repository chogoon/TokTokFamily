import {
  buildBoardSlots,
  buildGoalProgressText,
  isGoalReached,
  sortPraisesByNewest,
} from "./praises";
import { PraiseEntry } from "../types/praise";

describe("isGoalReached", () => {
  it("count가 target보다 작으면 false", () => {
    expect(isGoalReached(3, 10)).toBe(false);
  });

  it("count가 target과 같으면 true", () => {
    expect(isGoalReached(10, 10)).toBe(true);
  });

  it("count가 target보다 크면 true", () => {
    expect(isGoalReached(12, 10)).toBe(true);
  });

  it("count=0이면 false", () => {
    expect(isGoalReached(0, 10)).toBe(false);
  });
});

describe("buildBoardSlots", () => {
  it("count=0이면 전부 false", () => {
    expect(buildBoardSlots(0, 10)).toEqual(Array(10).fill(false));
  });

  it("count가 target보다 작으면 앞에서 count개만 true", () => {
    const slots = buildBoardSlots(3, 10);
    expect(slots).toHaveLength(10);
    expect(slots.slice(0, 3)).toEqual([true, true, true]);
    expect(slots.slice(3)).toEqual(Array(7).fill(false));
  });

  it("count=target이면 전부 true", () => {
    expect(buildBoardSlots(10, 10)).toEqual(Array(10).fill(true));
  });

  it("count가 target을 초과해도 길이는 target만큼이고 전부 true", () => {
    const slots = buildBoardSlots(12, 10);
    expect(slots).toHaveLength(10);
    expect(slots).toEqual(Array(10).fill(true));
  });

  it("target이 0이면 빈 배열", () => {
    expect(buildBoardSlots(0, 0)).toEqual([]);
  });
});

describe("buildGoalProgressText", () => {
  it("목표 텍스트와 진행도를 n/target 형태로 보여준다", () => {
    expect(buildGoalProgressText("보드게임 사기", 3, 10)).toBe(
      "🎯 10개 모으면: 보드게임 사기 (3/10)"
    );
  });

  it("count가 target을 초과해도 진행도는 target으로 고정한다", () => {
    expect(buildGoalProgressText("보드게임 사기", 12, 10)).toBe(
      "🎯 10개 모으면: 보드게임 사기 (10/10)"
    );
  });

  it("goalText가 비어있으면 기본 안내문을 쓴다", () => {
    expect(buildGoalProgressText("", 0, 10)).toBe(
      "🎯 10개 모으면: 목표를 정해주세요 (0/10)"
    );
  });
});

describe("sortPraisesByNewest", () => {
  const base: PraiseEntry = {
    id: "p1",
    boardId: "board-1",
    giverId: "member-parent",
    giverName: "엄마",
    text: "숙제를 혼자 했어요",
    createdAt: "2026-10-20T09:00:00.000Z",
  };

  it("createdAt 내림차순으로 정렬한다", () => {
    const older: PraiseEntry = { ...base, id: "p-older", createdAt: "2026-10-19T09:00:00.000Z" };
    const newer: PraiseEntry = { ...base, id: "p-newer", createdAt: "2026-10-21T09:00:00.000Z" };

    const result = sortPraisesByNewest([base, older, newer]);
    expect(result.map((p) => p.id)).toEqual(["p-newer", "p1", "p-older"]);
  });

  it("빈 입력이면 빈 배열", () => {
    expect(sortPraisesByNewest([])).toEqual([]);
  });

  it("원본 배열을 변경하지 않는다", () => {
    const list = [base];
    sortPraisesByNewest(list);
    expect(list).toEqual([base]);
  });
});
