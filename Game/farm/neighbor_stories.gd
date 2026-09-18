extends RefCounted
## Authored letters; progress is derived from durable deliveries, never UI visits.
const CHAPTERS := {
	"willow": [
		{"title":"把菜篮提回来", "group":"leaf", "amount":1,
		"letter":"这几天总在屋里吃饭，柳树下倒空着。我把旧菜篮洗了出来，想先炒一碗你种的青菜。吃过饭，再慢慢收拾院子。——林婶",
		"reply":"菜炒好了，脆生生的。我把菜篮搬到了屋前，往后你来，篮子就放在这里。坐在外头吃饭，才听见柳叶一直在响。",
		"change":"屋前添了收菜的竹篮。"},
		{"title":"旧晒架又有用处", "group":"root", "amount":1,
		"letter":"收拾菜篮时，找到了以前绑晒架的麻绳。想把萝卜切一半煮汤，另一半晾起来。带什么根菜都好，咱们试试不同的滋味。——林婶",
		"reply":"汤里添了菜，旧晒架也重新绑牢了。风从菜条间穿过去，和从前一样。没晾好的就慢慢晾，不急着收。",
		"change":"院里支起了挂菜的竹晒架。"},
		{"title":"再摆一张桌", "group":"aromatic", "amount":1,
		"letter":"许伯说，院子收拾好了，总该再摆张桌。我想请邻居来尝尝这几回的收成，还缺一点葱蒜香。你愿意的话，带一篮来就够。——林婶",
		"reply":"桌子摆好了，阿舟带了茶，许伯带了筷子。我原想着只是收拾旧东西，现在屋前成了大家能坐一坐的地方。以后有菜就换着吃，空手来也好。",
		"change":"晒架旁添了待客的小桌与收成。"}],
	"bamboo": [
		{"title":"竹箱里的一点绿", "group":"any", "amount":1,
		"letter":"做竹活剩下两只浅箱，扔了可惜，正好育一点菜苗。忙着填土，午饭还没顾上。你种了什么，就给我带一篮什么吧。——许伯",
		"reply":"饭吃好了，两只浅箱也装上了土。第一茬小苗已经安顿在屋前，叶子挨着竹边，显得院子都年轻了些。以后你来，咱们一起看看它们。",
		"change":"屋前摆出了两只育苗竹箱。"},
		{"title":"晒一晒竹匾", "group":"stem", "amount":1,
		"letter":"小苗站稳了，我又编了几只匾，想拿来晒菜。先炒一碟芹菜解解馋，余下的竹匾放在院里见见阳光。——许伯",
		"reply":"芹菜脆，竹匾也干爽了。我把家里的菜片和辣椒摊上去，林婶还教我留些空隙。原来编竹子的手艺，也能把一顿饭照料好。",
		"change":"院里多了晾晒菜片的竹匾。"},
		{"title":"竹下有客", "group":"leaf", "amount":2,
		"letter":"苗箱和竹匾都摆齐了，屋前还差一点人气。我想请林婶和阿舟来吃顿饭。凑两篮叶菜就好，混着品种也好看。——许伯",
		"reply":"桌子摆在竹影里，大家把几种菜混着炒了一盘。竹箱里种的是下一顿，桌上吃的是这一顿。往后做竹活做累了，就来这里歇歇。",
		"change":"竹影里摆出一张小桌，院子成了歇脚处。"}],
	"ferry": [
		{"title":"归舟这一顿", "group":"root", "amount":1,
		"letter":"刚把船拴好，带回来的篮筐还堆在门边。想煮点热汤，再慢慢收拾。若有一篮根菜，萝卜、胡萝卜都合适。——阿舟",
		"reply":"热汤下肚，船上的篮筐也搬到了岸上。以前总把屋子当落脚处，这次想住得像个家，先从屋前这一小块地方开始。",
		"change":"屋前安顿了从船上带回的竹篮。"},
		{"title":"留住一点味道", "group":"aromatic", "amount":1,
		"letter":"林婶送来几只陶罐，说能腌一点小菜。我想试着留些家里的味道，下次回来就有得吃。还缺一篮葱蒜或香菜，借一点香气。——阿舟",
		"reply":"陶罐摆好了，盖子也扣妥了。第一次拌得淡了些，林婶说慢慢试就行。有了这些罐子，屋前不再只是堆行李的地方。",
		"change":"屋前添了装家常小菜的陶罐。"},
		{"title":"回来的地方", "group":"any", "amount":2,
		"letter":"我把门前收拾开了，想请大家来吃一顿归舟饭。你带两篮喜欢的菜吧，种类随你。饭后也不用急着走，坐着看看湖。——阿舟",
		"reply":"大家把菜摆上了小桌。许伯说，下回回来，隔着水看见桌子就知道能坐下吃饭。我忽然觉得，船拴住的不只是一截绳，是一个愿意回来的地方。",
		"change":"屋前有了共食的小桌，归舟后可以在此坐下。"}],
}

static func chapter(id: String, index: int) -> Dictionary:
	if not CHAPTERS.has(id) or index < 0 or index >= CHAPTERS[id].size(): return {}
	return CHAPTERS[id][index].duplicate(true)

static func delivered(id: String, visit: Dictionary) -> int:
	return mini(int(visit.round) + int(visit.pending), CHAPTERS[id].size())

static func history(id: String, visit: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index: int in delivered(id,visit): result.append(chapter(id,index))
	return result
