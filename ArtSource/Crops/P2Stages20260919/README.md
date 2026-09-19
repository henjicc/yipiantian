# 蔬菜三阶段 P2 重制 · 2026-09-19

本批正在制作，尚未整体替换游戏。用户授权重制全部十二种蔬菜的苗／中期／成熟阶段；已认可的青菜成熟株保留，另重制其幼苗与中期，共35个独立阶段。完成后继续架下藤蔓种植、夜间高挂灯笼和可选画质优化。Tripo生成不设用户额度上限；Codex额度卡最多使用两张，接近1%时核查再用，目前本任务未使用。

## 每个阶段的生产流程

1. 按具体品种搜索真实照片，区分子叶、真叶、叶柄、株型及可采收形态。照片只作形态研究；记录直接来源，不将照片直接当游戏纹理。
2. 固定青菜v1、全景v1风格参考；图片工具分别生成每个阶段单体，检查物种与阶段特征、工笔细线、淡彩、完整连接、薄叶体积。错误先修参考，不能靠三维生成猜补。
3. P2-20260801独立生成每阶段，v3.5-20260815 detailed色图、delight=false、original_image、pbr=false。拓扑与面数按阶段记录：多数采用quad=true，雪里蕻中期／成熟采用三角输出。保留原模、服务回显、任务及实付费用，不把拓扑格式或面数当作质量保证。先实测代表株再扩大。
4. Blender整理副本，保留原始FBX／GLB和可编辑blend；按根颈→生长中心视觉扶正，统一土面锚点及阶段尺度。不得复用青菜-20°为通用角度，不得以缩小成熟株代替中期；审计几何、UV、纹理并重导入。
5. Godot替换对应资源，保留笔触，按各阶段实际接地设置土面和风动约束；正侧背、昼夜、阶段切换和目标镜头检查。模型成功不等于画面通过。
6. 每阶段保留参考、完整提示词及输入顺序、原始模型、任务与费用、处理参数、审计、正式落点、证据与采用状态。已有截图可重现，不为节点自动录屏。

## 形态研究

### 小葱 Allium fistulosum

- 查询：`Allium fistulosum seedling young harvested plant`、`scallion seedlings tubular leaves`。以 [UMN Extension 小葱资料](https://extension.umn.edu/garden-and-home/yard-and-garden/gardening-in-minnesota/growing-scallions-in-home-gardens)（Marissa Schuh／Jill MacKenzie，2024复核）确认葱白与绿色叶，不形成洋葱式膨大球茎；不混用同页另述的楼葱，也不将明尼苏达播期套用江南。
- 已查看 Salicyna 的[细苗实拍，2020-09-22](https://commons.wikimedia.org/wiki/File:Allium_fistulosum_2020-09-22_2857.jpg)和[生长株，2021-05-30](https://commons.wikimedia.org/wiki/File:Allium_fistulosum_2021-05-30_6548.jpg)（CC BY-SA 4.0）；苗为细长弯钩形子叶与初生管状真叶，照片中的阔叶杂草不是小葱子叶。中期采用少量上举管状叶和细短假茎。
- 成熟株参考 Forest and Kim Starr 的[田间种植实拍，Kula Maui，2009-05-19](https://commons.wikimedia.org/wiki/File:Starr-090519-8038-Allium_fistulosum-crop-Kula-Maui_(24328807153).jpg)与[收获实拍，Midway Atoll，2017-06-27](https://commons.wikimedia.org/wiki/File:Starr-170627-0204-Allium_fistulosum-harvested-Hydroponics_Greenhouse_Sand_Island-Midway_Atoll_(36319964331).jpg)（Commons页面标注CC BY 3.0 US）。前者用于直立管叶株型，后者用于葱白及渐变连接，不采用切断、枯黄叶和运输车。照片只作形态参考，本地副本在 `.local/crop-research-20260919/scallion-*`，不作为游戏贴图发布。
- 三阶段分别为两枚细芽、三片长管叶加一片初生叶、双芽小丛的七片管叶。成熟首张工笔参考把叶尖画成切开的管口，已在图片工具中修成自然闭合尖端，并增加前后遮挡，再提交P2。完整提示词与修订保存在 `scallion/<stage>/image-record.json`。

### 菠菜 Spinacia oleracea

- 查询：`spinach seedlings cotyledons first true leaves`、`spinach growing plant rosette`。
- 一手农场实拍：[Rava Ranches spinach process](https://ravaranches.com/spinach.html)，[子叶与初生真叶](https://ravaranches.com/images/sp8.jpg)、[生长期](https://ravaranches.com/images/sp9.jpg)、[可收获阶段](https://ravaranches.com/images/sp10.jpg)。已逐张查看；本地研究副本在 `.local/crop-research-20260919/`，不作为游戏资源发布。
- 苗：两片细长子叶、中心初生椭圆真叶、细绿短茎；不能画成青菜的宽圆子叶与白梗束。
- 中期：独立疏松莲座，约5–6片椭圆到略三角真叶，细长绿叶柄，无成熟密冠；成熟：更多开展真叶、清晰主脉，叶片有自然起伏，未抽薹开花。
- 首张苗参考子叶过宽，已通过图片工具收窄并减细叶柄，修订图供P2输入；历史输出保留工具原位置。

### 青菜 Brassica rapa Chinensis Group

- 查询：`bok choy seedling young plant`。
- [NC State 植物资料与多阶段实拍](https://plants.ces.ncsu.edu/plants/brassica-rapa-chinensis-group/)：对照子叶、幼株、宽叶白梗成熟株。苗与幼株须另做，成熟沿用 `../Greens/p2-gongbi-20260918/`。
- 本轮直接查看 [UF/IFAS HS1337](https://ask.ifas.ufl.edu/publication/HS1337) 图2（Jieli Qiao，贵阳）的一对有浅缺口子叶、初生倒卵形真叶；[原照片](https://ask.ifas.ufl.edu/image/HS1337/Duc3juktyo/Dxqbeec8fc/Dxqbeec8fc-2048.webp)。中期对照NC State收录的 [cristina.sanvito幼株实拍](https://eit-planttoolbox-prod.s3.amazonaws.com/media/images/6191829669_e3e8061d7_6wjM4xD8nOQG.jpeg)（CC BY 2.0），只参考前景青菜，不混用后方卷叶生菜。另查看 [Lynn Greyling育苗照片](https://www.publicdomainpictures.net/en/view-image.php?image=120759&picture=bok-choy-seedlings)（CC0），确认子叶至初生真叶的过渡。实拍仅作形态研究，不作为游戏纹理发布；本地副本在 `.local/crop-research-20260919/greens-*`。
- 苗为两片浅缺口圆肾形子叶、一大一小初生真叶及短细茎；中期为五片疏松的匙形真叶，叶柄开始增宽但不形成成熟粗白梗束。中期参考首图偏扇形且梗过粗，已修为较细叶柄和有近远遮挡的放射叶丛；完整原始／修订提示词保存在阶段 `image-record.json`。

### 白萝卜 Raphanus sativus Longipinnatus Group

- 查询：`daikon radish cotyledons young plant foliage`。一手资料：[UF/IFAS Daikon Radish Cultivation Guide](https://ask.ifas.ufl.edu/publication/HS1370)，Mary Dixon、Guodong Liu；图2为B形子叶与初生真叶，图4为六周左右叶丛与根肩，图5为完整白色长根。仅使用形态资料，不将佛罗里达播期作为江南播期。
- 已查看原照片：[苗](https://ask.ifas.ufl.edu/image/HS1370/Dtgqq3nrak/Db44omhw24/Db44omhw24-2048.webp)、[叶丛／根肩](https://ask.ifas.ufl.edu/image/HS1370/Dtgqq3nrak/Dhsg8pruk1/Dhsg8pruk1-2048.webp)、[长白根](https://ask.ifas.ufl.edu/image/HS1370/Dtgqq3nrak/Dod31lb2jk/Dod31lb2jk-2048.webp)。本地研究副本 `.local/crop-research-20260919/radish-{seedling,growing,mature}.webp`，不作为游戏贴图发布。
- 苗以一对肾形／B形子叶区别于菠菜细长子叶；中期为少量有齿裂叶、细根；成熟为展开裂叶莲座和膨大的长白根，根肩允许露出土面。
- 成熟首轮 `064418f8-421f-4aef-a3d4-ecaa6f3703fe` 已生成并入隔离实景检查，但叶冠深度只有.117米、横展.45米，侧面呈扇状，因此不作为最终版本。原件、原参考、整理源与参数保存在 `radish/history/mature-flat/`，120积分计入未采用费用。新参考改为高位斜俯视，明确前后叶片与根肩遮挡，重新生成验证，不能以任务成功或测试通过掩盖侧面体积不足。

### 生菜 Lactuca sativa，绿色散叶类型

- 查询：`lettuce seedling cotyledons true leaves`、`green loose-leaf lettuce plant`。沿用游戏既有散叶生菜类型，不换成长叶莴苣或结球生菜。
- [Rutgers 温室生产实拍序列](https://horteng.envsci.rutgers.edu/lettuce_production.htm)：[苗](https://horteng.envsci.rutgers.edu/images/fhgreenhouse/seedlings_in_rockwool.jpg)与[移栽幼株](https://horteng.envsci.rutgers.edu/images/fhgreenhouse/initial_spacing2.jpg)，已查看子叶和初生真叶。该照片只提供形态，不将温室水培天数套用到游戏或江南播期；后期远景照片无法辨认单株细节，未用作成熟参考。
- [University of Delaware 散叶生菜资料](https://www.udel.edu/academics/colleges/canr/cooperative-extension/fact-sheets/leaf-lettuce/)，2024-10，Rick Judd／Gail Hermenaus；已查看页面三张种植照片，成熟参考取第三张绿色植株的波浪叶缘与层叠叶丛，不混用其中红叶类型。研究副本在 `.local/crop-research-20260919/lettuce-*`，只作形态参考，不作游戏纹理发布。
- 苗为两片无缺口的椭圆匙形子叶、一大一小真叶；中期为少量开展的波浪边真叶；成熟为宽阔、皱褶更明显的层叠散叶莲座。三张独立工笔参考，成熟首图偏扇形且菜梗过长，图片工具修订近远叶遮挡与短绿色基部后再生成P2。完整提示词与输入顺序见 `lettuce/<stage>/image-record.json`。

### 香菜 Coriandrum sativum

- 查询：`cilantro seedlings cotyledons young plant`、`coriander mature plant leaves before bolting`。依据 [Wisconsin Horticulture 香菜资料](https://hort.extension.wisc.edu/articles/cilantro-coriander-coriandrum-sativum/)（Susan Mahr，University of Wisconsin–Madison）的实拍：[苗](https://hort.extension.wisc.edu/files/2017/02/Cilantro-seedlings-300x214.jpg)、[幼株](https://hort.extension.wisc.edu/files/2017/02/Cilantro-young-244x300.jpg)、[成株](https://hort.extension.wisc.edu/files/2017/02/Cilantro-plant-300x240.jpg)、[叶片细节](https://hort.extension.wisc.edu/files/2017/02/Cilantro-leaves.jpg)。本地研究副本 `.local/crop-research-20260919/coriander-*`，只研究形态，不作游戏贴图。
- 苗有成对狭长子叶与初生圆齿裂叶；中期约五片疏松真叶和细绿叶柄；成熟为圆齿分裂叶组成的叶丛，表示抽薹前可采收状态，不使用花序或抽薹后的羽毛状叶。原文的国外播期不作为江南播期依据。
- 中期、成熟首张工笔图叶面过于正对镜头，图片工具先修订叶片朝向、卷曲和前后遮挡，再提交P2。完整初始与修订提示词、输入和选定原图路径见阶段 `image-record.json`。

### 茼蒿 Glebionis coronaria，中叶裂叶类型

- 查询：`Glebionis coronaria seedlings cotyledons`、`春菊 双葉 本葉 発芽 写真 栽培`。采用种植者 [Plantersaien 从播种到采收的实拍](https://plantersaien.com/shungiku/)（2021-08-14）：[子叶与初生真叶](https://plantersaien.com/wp-content/uploads/syungiku-3646-680x454.jpg)、[幼株](https://plantersaien.com/wp-content/uploads/syungiku-3916-680x454.jpg)、[茎叶生长期](https://plantersaien.com/wp-content/uploads/syungiku-4046-680x454.jpg)、[采收叶丛](https://plantersaien.com/wp-content/uploads/syungiku-4516-680x454.jpg)。四图已查看，本地研究副本 `.local/crop-research-20260919/chrysanthemum-*`，不作为游戏贴图。
- 另以 [Takii 茼蒿栽培手册](https://www.takii.co.jp/tsk/manual/shungiku.html)区分大叶浅裂、中叶与小叶类型。本次统一中叶裂叶株型，不混入观赏菊花或大叶圆叶品种，不把日本播期套用江南。
- 苗为两片光滑椭圆子叶、两片大小不同的初生裂叶；中期为短茎上疏松的羽状裂叶；成熟主茎与短侧枝承载更多叶片，表示未开花的采收状态。中期、成熟首图偏平面，出图阶段先修订朝向、叶片前后遮挡与中期茎节，完整提示词留于各阶段 `image-record.json`。

### 芹菜 Apium graveolens Secalinum Group，中国细梗类型

- 查询：`celery seedlings cotyledons first true leaves photo`、`Chinese celery young plant Apium graveolens secalinum growing`。沿用原游戏中国芹菜类型，不改成粗白梗西芹或根芹。
- 苗参考种植者 [Wired Homestead](https://wiredhomestead.com/how-to-tell-if-seedlings-are-ready-to-transplant/)（Chris Larson，2026-02）的[子叶](https://wiredhomestead.com/wp-content/uploads/2026/02/celery-seedlings-e1770487128164-1024x768.jpg)与[初生真叶](https://wiredhomestead.com/wp-content/uploads/2026/02/celery-seedlings-with-1-true-leaf-e1770487060614-1024x768.jpg)照片：狭长椭圆子叶、最初三浅裂齿叶；并查看 [Home Microgreens真叶实拍](https://homemicrogreens.com/what-are-true-leaves/)核对初生叶形，其芹菜照片不包含可辨认子叶，不能混作子叶依据。
- 幼株参考 [Succeed Heirlooms中国芹菜](https://www.succeedheirlooms.com.au/heirloom-vegetable-seed/heirloom-celery-celeriac-seeds/chinese-celery.html)的[幼株照片](https://www.succeedheirlooms.com.au/images/chinese-celery-plant.jpg)，细长绿叶柄与上端分裂锯齿小叶；该页面主产品图也是同株缩图，不把它当另一张成熟实拍。成熟补看 [Johnny's cutting celery](https://www.johnnyseeds.com/herbs/herbs-for-salad-mix/cutting-celery-herb-seed-922.11.html)的[采收叶丛照片](https://www.johnnyseeds.com/dw/image/v2/BJGJ_PRD/on/demandware.static/-/Sites-jss-master/default/dw0a482041/images/products/herbs/00922_01_cuttingcelery.jpg?sh=800&sw=800)；表达开花前的叶柄／叶丛，不加入花序。
- 实拍已逐张查看，本地副本 `.local/crop-research-20260919/celery-*`，只作形态研究。国外播期、移栽或反复采叶操作不作为江南播期或新玩法依据。三张工笔参考已独立生成，首轮叶面过于正对镜头，已修订叶片朝向、杯状弯曲与前后遮挡；苗另收窄子叶。提示词与原件路径见 `celery/<stage>/image-record.json`；三阶段P2及运行检查已完成，见下方接入节点。

### 雪里蕻 Brassica juncea var. multiceps，绿色锯齿叶类型

- 查询：`雪里蕻 幼苗 子叶 真叶 图片`、`green in snow mustard seedlings`。品种名与绿色锯齿叶形核对 [RHS资料](https://www.rhs.org.uk/plants/362085/brassica-juncea-var-multiceps/details)，不采用其英国播期作为江南依据。
- 子叶近照取种植者Todd Marsh的 [Home Microgreens说明](https://homemicrogreens.com/what-are-true-leaves/)及[原图](https://homemicrogreens.com/wp-content/uploads/2019/03/what-are-true-leaves-cover-1024x683.jpg)，为Purple Wave叶用芥菜，**不是雪里蕻专属品种实拍**；只借其成对心肾形有缺口子叶与初生齿叶结构，不复制紫色或成熟叶形。
- 幼株依据 [央广网2024-11-20镇远雪里蕻补苗报道](https://gz.cnr.cn/dishizhibo/20241120/t20241120_526982134.shtml)中镇远县融媒体中心两张现场照片，查看前景少叶、细叶柄的低矮开展株型。图片说明用了“丰收”，但画面和正文实为移栽幼株，不能当成熟株依据。仅采用形态，不新增移栽玩法。
- 长叶轮廓核对 [Seeds of Scotland Green in Snow](https://www.seedsofscotland.com/products/mustard-green-green-in-snow)的[六片采下叶照片](https://www.seedsofscotland.com/cdn/shop/files/mustard-green-in-snow-new-2024-25-salad-222.webp?v=1723991956&width=1000)：长椭圆至披针形、浅裂与不规则锯齿、浅色主脉。研究副本名为 `mustard-young.webp`，实际是离体叶片，不能声称是独立幼株实拍。
- 成熟叶丛参考种子生产者 [Meraki Seeds](https://merakiseeds.com/green-in-snow-mustard)的[植株照片](https://merakiseeds.com/images/thumbs/0003979_green-in-snow-mustard_510.jpeg)，保留绿色、多层叶丛与锯齿叶缘，排除花薹。以上实拍均已查看，本地 `.local/crop-research-20260919/mustard-*` 只作研究，不作为游戏贴图发布。
- [Shu Suehiro雪里红生长序列](https://www.botanic.jp/plants-sa/seturi.htm)文字可读，但本机图片下载累计五次连接失败后停止，未将其照片写成已查看证据。三个阶段工笔参考独立生成，首版偏平，图片工具修订杯状弯曲、叶背和侧向朝向；提示词与输入在 `mustard/<stage>/image-record.json`，最终采用与验收见下方雪里蕻节点。

### 乌塌菜 Brassica rapa subsp. narinosa，照片调查

- 查询 `tatsoi seedling cotyledons young plant photo grow`、`乌塌菜 幼苗 莲座 生长 图片`。已查看种植者Todd Marsh的[育苗过程](https://homemicrogreens.com/how-to-grow-tatsoi-mustard-microgreens/)及[子叶实拍](https://homemicrogreens.com/wp-content/uploads/2023/06/tatsoi-mustard-microgreens-tray-side-view.jpg)：成对心肾形子叶带浅缺口、细绿茎；育苗盘密播的徒长高度不直接复制到农田苗。
- 已查看 [Plantura幼株照片](https://plantura.garden/uk/wp-content/uploads/sites/2/2022/03/young-tatsoi-plant-1024x683.jpg)（Pengejar Senja／Shutterstock，来源[文章](https://plantura.garden/uk/vegetables/tatsoi/tatsoi-overview)）：圆匙形深绿真叶、细长浅绿叶柄从短茎基部放射展开；盆栽图只用于形态，不复制土袋。
- 已查看 [Botanical Interests产品实拍](https://shop.epicgardening.com/products/rosette-tatsoi-bok-choy-seeds)（Kelly Roy）：成熟叶丛匙形叶、皱缩表面、密集放射排列；该近照只提供叶面特征，页面的手绘苗图未冒充实拍。
- 补看 [Plantura在田整株照片](https://plantura.garden/uk/wp-content/uploads/sites/2/2022/03/growing-tatsoi-1024x681.jpg)（homi／Shutterstock）：中间完整植株为低矮放射莲座，外叶近水平、内叶立起；[成熟近照](https://plantura.garden/uk/wp-content/uploads/sites/2/2022/03/tatsoi-plant-leaves-1024x683.jpg)（SPBShutter／Shutterstock）用于皱褶。另查看[NC State资料](https://plants.ces.ncsu.edu/plants/brassica-rapa-var-rosularis/)所载Forest & Kim Starr的株型、叶丛和育苗实拍（页面标CC BY 2.0）。其“Seedlings”图已有数片真叶，归作幼株依据，不能当刚萌发子叶图。
- 本地照片与原图URL在 `.local/crop-research-20260919/tatsoi-*`；只作研究，未作为游戏贴图发布。三个阶段工笔参考各自生成，首图偏扇形，已修订近远叶片遮挡与细绿叶柄，完整提示词及输入见 `tatsoi/<stage>/image-record.json`；P2模型已接入并通过下方节点验证。此处不采纳国外播期作为江南9月依据。

### 胡萝卜 Daucus carota subsp. sativus

- 查询 `carrot cotyledons first true leaves seedlings photo extension`、`carrot growth stages young mature plant photos extension`。打开并查看 [UF/IFAS AE588](https://ask.ifas.ufl.edu/publication/AE588) 的[图4实拍组图](https://ask.ifas.ufl.edu/image/AE588/Daommp9azk/Ig9at6nae9/Ig9at6nae9-2048.webp)：A为萌发，B为细长子叶及第一裂叶，C/D为早期储藏根与疏松叶丛，E–H为膨大橙根及较密的羽状叶丛。A/B署名garden.eco／mytinyplot.com，C–H为Vivek Sharma、Robert Hochmuth、Morgan Morrow（UF/IFAS）。本地 `carrot-ifas-stages.webp` 仅作形态参考，不作为发布纹理。
- 苗采用两片细长不分裂子叶和初生裂叶，无膨大根；中期为少量二回羽状叶和细小渐膨大的橙根；成熟为更多细裂复叶和单个饱满长锥形橙根，未抽薹开花。国外播期和真实天数不替换游戏节奏。图3为示意图，不冒充照片。
- 图片工具三个阶段独立出图。中期首轮叶裂偏宽、布局偏平，修为细裂羽状叶；成熟首轮修订后前叶过低，再抬至根肩附近，避免埋根时叶片入土。完整提示词、输入顺序和各版原图在 `carrot/<stage>/`；P2与运行验证进行中。

## 制作状态

- 菠菜三个阶段已完成独立参考／P2生成、Blender整理及游戏接入，见下方节点；用户审美反馈待收集。
- 白萝卜三个阶段已独立生成并接入；成熟首版因侧面过扁弃用，第二版经外叶姿态和根部接地整理后采用，见下方节点。
- 青菜幼苗与中期已独立生成并接入，成熟株原文件与材质保留。
- 生菜、香菜、茼蒿、芹菜、雪里蕻、乌塌菜、胡萝卜、小葱各三个阶段已独立生成并接入，通过定向与实景／风动检查；当前累计32／35个新阶段。青蒜共3阶段未完成；藤蔓玩法与整体光照未开始实现。
- 本批工作前存在模型目录／检查页及开发说明等其他改动，不属于本批，不覆盖或混入提交。当前仓库未配置远端。

## 菠菜接入节点 · 20260919-spinach-p2-stages

三个阶段各自依照上方实拍制作参考并生成；没有复用同一个苗或缩小成熟株。任务、尺寸、种子与实际费用见 [spinach/stages.json](spinach/stages.json)，完整图片提示词及输入在各阶段 `image-record.json`。每株120积分，共360积分；无分件、绑定、重贴图或减面费用。

| 阶段 | 实际三角形 | 实际高度 | 特征 |
|---|---:|---:|---|
| 苗 | 3818 | .085米 | 细长子叶、初生椭圆真叶、细绿茎 |
| 中期 | 6895 | .190米 | 疏松少叶莲座、独立叶柄 |
| 成熟 | 12841 | .280米 | 开展叶冠、更多自然起伏真叶 |

保留全部原始几何和4K色图，运行材质绕过旧增绿／压暗；没有照搬青菜的-20°扶正角或色温数值。采用菠菜独立微风，主摆幅最多6毫米、叶缘扰动1.6毫米、下部18%约束、节奏.82；各阶段再按高度限制摆幅，苗不会跟成熟株一样大幅移动。没有逐叶分割或骨骼。

原始四边面FBX、服务回显、参考、预览、可编辑blend、导出GLB及 `asset-audit.json` 分阶段保存。苗的诊断开边为0；中期847、成熟1330，包含薄叶开放边，不能宣称全部水密。源／导出四向与双面运行材质检查未见影响目标画面的大片缺面；未盲目补洞。原始成熟模的诊断副本曾有4个接近零面积面，缩放后的统计为0，此统计依赖阈值，不能解释成已执行几何修复。重建：Blender 5.2运行 `prepare.py -- spinach <sprout|young|mature>`，检查后加 `--install` 安装，再运行项目Godot Import。

接入发现细根土粒仅缩窄XZ而保留高度，形成针状突起；`soil.gdshader` 现同步缩放土粒高度及法线、重新贴合连续地表，土丘高度也随根部足迹收敛，成熟青菜大足迹保持既有高度。不是增大苗的土圈掩盖问题。

验证：`tests/crop_assets_test.gd -- --crop=spinach` 87项通过，相关青菜82项通过；`tests/soil_presentation_test.gd` 播种／收获／相邻格交互通过。四向单体、农场正反面／昼夜、全景与聚焦、修正土粒后的画面在 `.local/verification/p2-stages/spinach/`，相关土壤对照在 `../soil/`。独立固定相机风动两帧5820像素变化，关闭风动后0，根部约束另由参数检查；像素变化只证明风动生效，不代替审美验收。土壤截图测试退出有12个ObjectDB／6个资源释放告警，非材质编译失败。

制作素材节点：本地 `制作留档/03_处理与验证/20260919_蔬菜三阶段P2重制/README.md`。已有参考、原模预览、源文件和运行截图，无新录像；可按保存源重现补拍，未更新独立发行包。

## 白萝卜接入节点 · 20260919-radish-p2-stages

按UF/IFAS实拍分别制作肾形子叶苗、少量齿裂真叶幼株和有膨大白根的成熟株；参考、完整提示词、原始FBX和服务任务、可编辑blend、GLB与审计均按阶段保存。现役任务及重建参数见 [radish/stages.json](radish/stages.json)。三个采用阶段360积分，另有未采用的成熟扁冠首版120积分，萝卜合计480积分；本批连同菠菜累计840积分，无新增分件、绑定或重贴图费用。

| 阶段 | 运行三角形 | 土面以上高度 | 处理 |
|---|---:|---:|---|
| 苗 | 3852 | .085米 | 保留B形子叶与初生真叶，根部落地 |
| 中期 | 4964 | .146米 | 细根埋入土面，清理1个无面孤点，所有面保留 |
| 成熟 | 9110 | .172米 | 原始9112三角中移除2个严格零面积三角和随之孤立的2个点；保留其他全部面与4K颜色 |

成熟第二版原始叶冠已有前后体积，但外叶沿白根下垂，直接入土会穿土。Blender在整理副本中按已检查的空间范围选取完整连通的外叶／叶柄组件，绕实际冠部刚性旋转70°，保留UV、薄叶形态，排除储藏根和根须；不是Tripo语义分件或骨骼绑定。现役叶冠宽.450、深.334米，完整根叶高.358米，根尖在土面下.186米。矩阵、选区、根部锚点与接触半径在阶段参数／审计中保存，这些坐标只适用于该模型，不作其他植物预设。原始FBX不可变，可从 `prepare.py -- radish <stage> --install` 重建。历史扁冠版本另存，不能用其审计代表现役版本。

成熟根部接触半径约.028／.029米；根尖至75%高度固定，主摆幅最多5毫米、叶缘1.5毫米，并按阶段高度限幅，白色储藏根不会随叶冠弯摆。三个阶段均保留原工笔颜色，禁用自动LOD并使用同一完整资源，避免低档路径重新显示旧萝卜。苗0开边；中期2794、成熟4790条诊断开边，含开放薄叶，不宣称水密。近看仍有少量源叶片小孔／边缘缺口；没有以盲目封孔破坏裂叶轮廓，开发接入不代表用户审美签收。

验证：萝卜93项定向资产检查通过；相关菠菜93项、青菜88项已通过。原模、四向单体、三阶段农场正反昼夜见 `.local/verification/p2-stages/radish/`、`radish-v2/`；成熟调整后在 `radish-final/`，风动两帧9387像素变化、关闭后0。实景穿土修正与姿态对比可从保存源复现；材质没有编译错误。隔离实景截图进程退出曾报12个ObjectDB／6个资源仍在使用的清理告警，截图正常完成。没有新录像或独立发行包更新。

本次可复用经验：根菜的土面锚点应取储藏根截面，不能取整株最低点，也不能让跨过同一高度的外叶决定根部中心。根须、叶柄可能是同一网格中的分离组件，调整叶姿须检查它们的归属；仅抬升所有低处顶点会扭曲根部。重建清理必须列出实际缺陷数量并核对三角数差额，不能放宽零面积断言绕过错误。

## 青菜幼年阶段接入节点 · 20260919-greens-p2-stages

依据上方实拍分别生成幼苗和中期，成熟株不重做。任务、种子、尺寸、费用与保留成熟模型的SHA256见 [greens/stages.json](greens/stages.json)，原始参考／修订提示词见各阶段 `image-record.json`。本轮两个P2任务各120积分，共240；全批累计1080积分。无新增重贴图、分件或绑定费用。

苗3794三角、.085米高，成对有缺口子叶＋初生真叶，0开边／非流形边；中期6502三角、.180米高，约五六片匙形真叶与细叶柄形成疏松立体叶丛，500条诊断开边、507条非流形边。中期仅清理1个无面孤点，全部面与4K色图保留；没有减面、补洞或强加统一扶正角。正侧背及实景未见大片缺叶，薄叶边缘有少量原生开口，不宣称水密。

根部原点在土面，接触半径分别.009／.009、.0148／.0142米。两个新阶段绕过旧增绿压暗，沿用青菜克制色温校正与慢风：下部45%固定，主摆最多3.5毫米、苗再按株高限幅，叶缘最多.6毫米、节奏.65。按具体阶段识别本批资源，幼苗和中期禁用自动LOD／旧低档路径，成熟高低档及其导入、材质、扶正保持原样；已复核成熟两个GLB的SHA256与制作前一致。

验证：青菜92项定向资产检查通过，覆盖新阶段审计、实际材质、土面和保留成熟高低档；四向单体、三阶段同田、正反昼夜与聚焦在 `.local/verification/p2-stages/greens/`。中期固定相机风动两帧422像素变化，关闭后0，证明风动生效；不作为审美结论。原始FBX、可编辑blend、GLB、任务与审计均已保存，可用 `prepare.py -- greens <sprout|young> --install` 重建。无新录像，独立发行包未更新，待用户审美反馈。

## 生菜接入节点 · 20260919-lettuce-p2-stages

按Rutgers幼苗／幼株实拍与Delaware散叶成株照片，各阶段独立生成工笔参考和P2模型。成熟参考在图片阶段修正扇形构图、长白菜梗；模型未重复生成。任务、种子和参数见 [lettuce/stages.json](lettuce/stages.json)，各阶段120积分，共360；全批累计1440积分。没有分件、绑定、重贴图或减面。

| 阶段 | 三角形 | 土面以上高度 | 形态与处理 |
|---|---:|---:|---|
| 苗 | 3947 | .085米 | 椭圆无缺口子叶、波浪边初生真叶，细茎接地 |
| 中期 | 6956 | .125米 | 疏松少叶莲座；完整高度.16米，原生成尖长基部埋入土面下.0352米 |
| 成熟 | 11458 | .280米 | 宽.453、深.457米的层叠散叶冠，侧面体积保留 |

全部原始面、UV及4K色图保留，0零面积面／孤点，无旋转或非等比变形。苗／中期／成熟诊断开边163／431／2596，中期另有26条非流形边；包含开放薄叶，不能宣称水密。四向与实景未见大片缺叶，近看保留少量原生小孔／边缘缺口，不盲目封孔改变叶缘。

中期根颈采用原始高度22%截面，土面足迹按实景根颈保留.0158／.0298米；同高度外叶会扩大整网格截面，所以审计同时记录全截面与人工检查的接触半径。苗与成熟足迹分别.009／.009、.0265／.0207米。三阶段绕过旧增绿压暗，不套用青菜色温校正，禁用自动LOD。复用适合柔薄叶的 `autumn_crop` 微风：主摆最多5毫米、叶缘1.5毫米、基部20%固定，另按株高限幅与土面约束；中期地下基部不会摆动。没有新增骨骼或粒子。

验证：`tests/crop_assets_test.gd -- --crop=lettuce` 93项通过；四向单体和三阶段实景正反面／昼夜／聚焦见 `.local/verification/p2-stages/lettuce/`。中期调整前单体保留作过程，最终土面效果以 `farm/` 为准。成熟风动固定两帧25091像素变化，关闭后0；不替代审美认可。原始FBX、任务、可编辑blend、GLB及审计已保存，重建为 Blender运行 `prepare.py -- lettuce <stage> --install` 后Godot Import。没有新录像或独立包更新，开发接入待用户审美反馈。

## 香菜接入节点 · 20260919-coriander-p2-stages

三阶段分别依照上述实拍制作工笔参考，再独立生成P2模型。任务、种子、整理参数见 [coriander/stages.json](coriander/stages.json)，每株120积分，共360；全批累计1800积分。成熟原任务通过CLI已保存的名称恢复查询，未因会话输出丢失重新付费提交。

| 阶段 | 三角形 | 土面以上高度 | 处理 |
|---|---:|---:|---|
| 苗 | 3863 | .0836米 | 狭长子叶与初生圆齿真叶，保留全部几何 |
| 中期 | 4962 | .170米 | 少量圆齿裂叶、细绿叶柄；清理背面两个生成球形杂物 |
| 成熟 | 11792 | .2675米 | 未抽薹的立体叶丛，宽.400／深.379米，保留全部几何 |

中期原模5122三角，两颗悬空球各42顶点／80三角；整理按已审查的原始坐标包围盒精确删除，并断言选择不切断相连表面、数量一致和三角差额正确。没有对植株减面，原始FBX不变。可复用经验：零孤点并不等于没有悬空杂物，完整的小封闭组件仍需正侧背检查；不要按组件大小批量删除细叶。三株0零面积面／孤点；诊断开边30／2465／5669、非流形边39／2466／5680，包含开放薄叶与少量原生细小孔隙，不宣称水密，未盲目补洞。

三阶段均无强加旋转、非等比变形，保留4K色图和工笔设色，不套青菜的色温参数，禁用自动LOD。接土半径苗.009／.009、中期.0126／.0144、成熟.0142／.0142米；成熟全网格12毫米切片受低垂外叶影响会扩大到.0659／.11米，因此只按真正基部设置足迹，并在审计同时留存原切片数值。成熟根部仍是整株最低处，无需抬高或埋深叶冠。

香菜细叶柄与薄叶沿用 `autumn_crop` 有界微风：主摆最多5毫米、叶缘1.5毫米、下部20%固定，幼苗按实际高度限制到2.5%／0.8%；土面以下不动。没有额外粒子、拆叶或骨骼。

验证：香菜93项定向资产检查通过；四向单体、三阶段实际农田正反面／昼夜和聚焦见 `.local/verification/p2-stages/coriander/`。`views/` 保留清理前中期杂物证据，最终清理及接土以 `farm/` 为准；14张实景截图进程正常退出。成熟固定风动两帧14537像素变化，关闭后0。夜间仍使用既有环境照明，后续灯笼／全场光照优化尚未完成。没有新录像或独立包更新，审美反馈待用户实际查看。

原始参考、提示词、任务回显、FBX、预览、可编辑blend、GLB及审计均按阶段保存。重建：Blender运行 `prepare.py -- coriander <sprout|young|mature> --install`，然后项目Godot Import。记录与重建均包含两球清理及成熟接土范围，不能只复制未经整理的原模。

## 茼蒿接入节点 · 20260919-chrysanthemum-p2-stages

依据上述种植实拍分别制作椭圆子叶／初生裂叶苗、少叶短茎幼株、带主茎与短侧枝的未开花成熟株。中期与成熟的平面构图先在参考阶段修订，再各生成一次P2；三个任务各120积分，共360，全批累计2160积分。完整任务、种子、整理参数见 [chrysanthemum/stages.json](chrysanthemum/stages.json)，原图与修订提示词保存在阶段 `image-record.json`。

| 阶段 | 运行三角形 | 土面以上高度 | 整理 |
|---|---:|---:|---|
| 苗 | 4128 | .085米 | 椭圆子叶与初生羽状裂叶，完整保留原面 |
| 中期 | 6890 | .1607米 | 原6896三角，移除6个严格零面积三角及清理后出现的1个孤点 |
| 成熟 | 11771 | .320米 | 移除1个无面孤点，全部面保留；中央主茎重新定位到原点 |

三阶段保留4K色图、UV与工笔设色，没有减面、强加旋转或非等比变形；也未套用成熟青菜色温参数。中期实际高度受.28米最大宽深约束，成熟宽.294／深.355米。整理后均0零面积面／孤点；诊断开边39／2834／7867、非流形边42／2865／7902，包含开放薄叶，不能宣称水密。双面材质四向与实景没有大片缺叶，少量原生小孔与叶缘缺口仍存在，没有盲目补洞改变裂叶形态。

接土半径分别.009／.009、.012／.010、.013／.013米。成熟默认最低1.2%切片混入低垂外叶，导致自动根部中心偏移；改用原坐标最低.006高度切片核对中央茎基部，中心为(.0093,.0039)，未埋深或抬高整株。中期与成熟的土粒范围也按真实茎基部限定，审计同时保留受外叶影响的整网格切片范围。复用经验：最低点附近也可能同时有叶尖，自动根部切片仍须核对实际茎基部，不能只缩小土圈而保留偏移的种植中心。

茼蒿独立风动固定下部30%，主摆最多5.5毫米、叶缘扰动1.5毫米，苗按株高限制到2.5%／0.8%；节奏为通用风速。比香菜多固定一段直立主茎，仍是连续网格柔性变形，没有拆叶、绑定或新增粒子。三个阶段禁用额外自动LOD，运行始终使用完整新资源。

验证：`tests/crop_assets_test.gd -- --crop=chrysanthemum` 93项通过；12张四向单体、14张实际农田正反面／昼夜与全景聚焦在 `.local/verification/p2-stages/chrysanthemum/`，截图进程正常退出。成熟固定相机两帧风动11383像素变化，关闭后0，证明风动生效而非审美认可。实景未见大片穿土；夜景仍采用既有照明，后续全场灯光优化未完成。

原始FBX不可变，参考、任务、预览、可编辑blend、GLB及审计齐全。重建：Blender运行 `prepare.py -- chrysanthemum <sprout|young|mature> --install` 后Godot Import。本地素材节点 `制作留档/03_处理与验证/20260919_茼蒿三阶段P2重制/README.md`；没有新录像或独立包更新，用户审美反馈待收集。

## 芹菜接入节点 · 20260919-celery-p2-stages

按上方实拍分别制作子叶与初生齿叶苗、较矮的疏松幼株、细绿长叶柄与分层复叶的未开花成熟株。参考先修订平面构图，再分别生成一次P2；三项各120积分，共360，全批累计2520积分。完整任务、种子及整理参数见 [celery/stages.json](celery/stages.json)。

| 阶段 | 三角形 | 高度 | 处理 |
|---|---:|---:|---|
| 苗 | 3197 | .085米 | 保留狭椭圆子叶与初生浅裂齿叶 |
| 中期 | 6643 | .200米 | 种植中心按中央茎丛定位，排除低垂外叶影响 |
| 成熟 | 14674 | .420米 | 保留细绿叶柄与多方向薄叶，宽.418／深.395米 |

三株全部原始面、UV与4K色图保留，无减面、非等比变形或额外扶正旋转，0零面积面／孤点。诊断开边885／3401／6416、非流形边887／3415／6468，包含薄叶开口及细小边缘缺口，不宣称水密；四向与实景检查未见大片缺叶，不盲目补洞。生成模型预览中的窄条须换方向确认叶面，不能仅以单张正面图判断脱落或删除小组件。

接土半径苗.009／.009、中期.014／.014、成熟.0192／.0208米。中期最低点位于外叶，自动切片会把种植中心偏到一侧；根据实际中央茎基部指定原坐标中心(-.0466,-.0310)。茎基部比最低叶尖高约2.8毫米，正反实景中与现有土粒相接，没有继续埋深整株。审计同时保留受低叶影响的整网格12毫米切片范围(.1054／.0750)，避免把它误作根部半径。

三阶段保留工笔原色，绕过旧增绿压暗，不套青菜色温校正，禁用额外自动LOD。芹菜独立微风固定下部35%，主摆最多4.5毫米、叶缘1.4毫米，幼苗按株高2.5%／0.8%限幅；使用通用风速。没有分件、骨骼、额外粒子或付费后处理。

验证：`tests/crop_assets_test.gd -- --crop=celery` 93项通过，导出重导入通过；12张四向单体与14张实景正反昼夜／全景聚焦在 `.local/verification/p2-stages/celery/`。已查看所有单体方向、三阶段日间正反面及夜间代表视角；成熟近景重点检查根部，顶部全貌结合单体和聚焦图判断。风动固定两帧18169像素变化，关闭后0；截图与风动进程正常退出。夜景仍偏暗，全场灯光优化尚未完成，不将本次材质检查写成夜间照明验收。

重建：Blender运行 `prepare.py -- celery <sprout|young|mature> --install` 后Godot Import。原始FBX、任务、参考／提示词、可编辑blend、GLB和审计按阶段保存。本地素材节点 `制作留档/03_处理与验证/20260919_芹菜三阶段P2重制/README.md`，无新录像或独立包更新，待用户审美反馈。

## 雪里蕻接入节点 · 20260919-mustard-p2-stages

按上方实拍区分肾形子叶／初生齿叶苗、少叶幼株、未抽薹的密集长齿叶丛，各自生成工笔参考及P2模型。现役任务及整理参数见 [mustard/stages.json](mustard/stages.json)。苗一次生成；中期和成熟各三次，七项均120积分，共840，全批累计3360积分。本次局部舒展没有新增生成或后处理费用。

| 阶段 | 运行三角形 | 高度 | 最终处理 |
|---|---:|---:|---|
| 苗 | 5272 | .085米 | 四边面FBX源，完整几何，子叶与初生齿叶独立于其他菜苗 |
| 中期 | 9322 | .190米 | 三角GLB源，整体X／Y各−3°校正基部；舒展两片下卷外叶 |
| 成熟 | 14362 | .340米 | 三角GLB源，移除1个严格零面积面；舒展两片下卷外叶 |

前两轮中期／成熟因轮廓未满足目标弃用，原件、参考、参数、blend与审计留在 `mustard/rejected-first/`、`rejected-second/`，不能用现役重建命令覆盖历史结果。第二轮与最终轮使用相同参考／种子，但同时改变拓扑格式和面数预算，因此不能把差异归因于单一开关。没有付费重贴图、语义分割、绑定或减面。

**卷叶诊断纠正：** 最终三角候选部分侧视图曾被判作大片破洞；提取连通单叶并从四个方向观察，确认主要疑似大洞是完整叶片过度下卷形成的拱形空隙。不能凭单张侧视图或PCA平面轮廓盲目补洞、删叶或再付费生成。当前中期／成熟各精确选择两片外叶，按原始组件顶点数与包围盒断言定位，以平滑权重降低远端的垂直弯曲，保留根部／叶柄连接、UV、原面和锯齿叶缘。没有复制别株或别阶段的叶片，也没有把网格焊合写回源模型。

苗／中期／成熟诊断开边0／3920／6671，非流形边0／3926／6709，整理后0零面积面／孤点；仍有薄叶开口和少量原生边缘小缺口，不宣称水密。三阶段保留4K色图及原工笔颜色，不套青菜的色温校正，禁用额外自动LOD。中期宽.204／深.228米，成熟宽.398／深.451米。接土半径分别.009／.0098、.012／.012、.0259／.0229米，中期锚点按真正中央基部确定，舒展后外叶不再抢占最低接土切片。

雪里蕻细叶柄、薄叶沿用有界 `autumn_crop` 微风：主摆最多5毫米、叶缘1.5毫米、下部20%固定，幼苗另按株高2.5%／0.8%限幅。最终风动两帧14203像素变化，关闭后0；没有骨骼或额外粒子。

验证：93项定向资产检查及Blender导出重导入通过。最终四向单体在 `.local/verification/p2-stages/mustard/relaxed-views/`，14张农场昼夜／正反面／全景聚焦在 `relaxed-farm/`，最终风动在 `relaxed-wind/`；已查看各阶段日间正反面、全部中期／成熟四向、夜间代表和聚焦。近景检查基部，成熟顶部全貌结合单体／聚焦判断。`young-part-angles.png`、`mature-part-angles.png` 是原生成单叶诊断，`final-farm/` 名称虽含final，实际是舒展前候选，不作最终采用证据。夜景仍偏暗，灯笼与整体光照优化尚未完成。

重建：Blender运行 `prepare.py -- mustard <sprout|young|mature> --install` 后Godot Import。源参考／提示词、原始模型、任务费用、可编辑blend、GLB及审计均已保存。本地节点 `制作留档/03_处理与验证/20260919_雪里蕻三阶段P2重制/README.md`；无新录像或独立包更新，用户审美反馈待收集。

## 乌塌菜接入节点 · 20260919-tatsoi-p2-stages

以子叶实拍、幼株和在田莲座照片分别制作参考，三个P2任务各120积分，共360，本批累计3720积分；没有用缩小成熟株替代幼苗／中期。版本、任务、请求面数、种子及重建参数见 [tatsoi/stages.json](tatsoi/stages.json)，原始与修订图片及完整提示词分阶段保存。

| 阶段 | 实际三角形 | 实际高／宽／深（米） | 形态和处理 |
|---|---:|---|---|
| 苗 | 4308 | .0621／.1200／.0706 | 两片带浅缺口子叶、两片初生真叶；根部切片混入低垂子叶，改按真正细茎基部定位 |
| 中期 | 8682 | .1205／.2800／.2800 | 少量圆匙形、轻皱真叶，放射排列的细绿叶柄 |
| 成熟 | 18251 | .1600／.3804／.3804 | 多层低矮莲座；原生成下部叶柄过高，局部缩短基部，保留上部叶片 |

Blender只在副本整理。成熟株对下部42%高度作平滑缩短，该区域终点高度保留40%，以上部分整体下移；没有整株压扁、删叶、补洞或改变UV。该参数只用于此株，不作为全部植物默认。幼苗根部XY为原生坐标(.08,−.024)，接土半径9毫米；中期接土半径.03221／.03132米，成熟.03726／.03234米。三阶段没有套用青菜−20°或色温校正。

各阶段保存不可变四边面FBX、服务回显、预览、4K色图、可编辑blend、GLB及审计。源与整理后三角数相同；苗／中期／成熟诊断开边264／0／321，非流形边264／0／692，零面积面与孤点均0。保留双面薄叶，四向检查未见影响目标镜头的大片缺面，不宣称全部水密。原有自动LOD禁用保持，当前不减面。

乌塌菜使用独立轻风：主摆最多3.5毫米、叶缘1毫米、下部35%固定、节奏.65，苗继续按高度2.5%／.8%限幅；保留原工笔色图，未作语义拆叶、骨骼或额外粒子。真实两帧风动5171像素变化，关闭后0。

验证：Blender导出重导入及93项乌塌菜定向资源检查通过。`.local/verification/p2-stages/tatsoi/final-views/` 为最终四向，`final-farm/` 为14张实际农场昼夜、正反面和全景／聚焦，`final-wind/` 为风动开关。已查看三阶段日间正反面、成熟四向、夜间代表与聚焦，基部接土、阶段体量和叶冠轮廓可辨。`initial-views/` 是根部修正／基部缩短前，不能作最终证据。夜景偏暗仍列入后续整体光照任务。用户审美反馈待收集，没有新增录屏或更新独立发布包。

重建：Blender 5.2运行 `prepare.py -- tatsoi <sprout|young|mature>`，检查后加 `--install`，再执行项目Godot Import；运行引用 `Game/art/crops/tatsoi/`。本地制作索引为 `制作留档/03_处理与验证/20260919_乌塌菜三阶段P2重制/README.md`。

## 胡萝卜接入节点 · 20260919-carrot-p2-stages

按UF/IFAS实际生长照片区分窄子叶苗、少叶细根中期与未开花成熟株，分别生成工笔参考和P2模型。三任务各120积分，共360，本批累计4080积分；中期与成熟参考经过细裂叶／外叶姿态修订，未使用放大苗或缩小成熟株替代阶段。精确任务、版本、种子与几何修整参数见 [carrot/stages.json](carrot/stages.json)，提示词和选图过程在各阶段image-record.json。

| 阶段 | 运行三角形 | 地上高／总高（米） | 处理 |
|---|---:|---|---|
| 苗 | 4632 | .085／.085 | 两片窄子叶和初生分裂真叶，根颈接土 |
| 中期 | 9468 | .1316／.2800 | 原9498三角，精确清除根下独立细丝18顶点／30三角；细储藏根入土 |
| 成熟 | 15495 | .2711／.4976 | 储藏根固定，抬起低垂叶冠，保留全部面与UV |

原始FBX保持不变。成熟株诊断合点仅用于识别组件：81个叶柄／小叶组件、9970个空间位置由同一径向高度场抬升，中心原坐标(.105,−.01)周围.03半径固定，外部按斜率.62逐渐抬起，避免单独移动小叶撕开连接。储藏根与根毛不参与变形，种植面固定在原生z=0，防止叶冠升高后包围盒比例改变种植深度；根部XY和接土半径分别按实际根肩定位。该参数只用于此株，没有采用青菜的统一旋转或色温。

三阶段保留4K工笔色图、单材质、双面薄叶与全部有效几何，无减面或额外自动LOD。苗／中期／成熟诊断开边151／4109／7898，非流形边180／4137／7915；整理后零面积面与孤点均0。中期和成熟有原生薄叶开口与小边缘缺口，四向及实景未见大片缺叶，不宣称水密。土粒接触半径分别(.009,.009)、(.015,.015)、(.028,.024)米，不把下垂叶片所在切片当作根肩范围。

胡萝卜独立微风主摆最多6毫米、叶缘1.8毫米，下部58%固定并覆盖储藏根，幼苗继续受株高2.5%／.8%限幅；保留原画颜色，未做语义拆叶、骨骼、付费后处理或额外粒子。最终真实两帧风动25637像素变化、关闭后0。

验证：Blender导出重导入及93项定向资产检查通过。`.local/verification/p2-stages/carrot/initial-views/`与`initial-farm/`保存全三阶段四向、昼夜正反面与聚焦；其中成熟株是抬叶前。最终成熟四向在`lifted-views/`，日夜正反面在`lifted-farm/`；风动在`final-wind/`。已查看三阶段日间正反面、所有单体方向、夜间代表与聚焦，最终成熟低叶避开土面、根部接地。近景取根部，顶部全貌结合单体图判断。夜景仍偏暗，后续灯笼与光效任务未完成。未录新视频或更新独立包，待用户审美反馈。

重建：Blender 5.2执行`prepare.py -- carrot <sprout|young|mature>`，检查后加`--install`，再运行项目Godot Import。源图、不可变原模、脱敏任务、blend、GLB和审计均按阶段保存；游戏引用`Game/art/crops/carrot/`。本地索引`制作留档/03_处理与验证/20260919_胡萝卜三阶段P2重制/README.md`。

## 小葱接入节点 · 20260919-scallion-p2-stages

按上方细苗、生長株及成熟葱白／田间实拍分别生成工笔参考，三个独立P2任务各120积分，共360，本批累计4440积分。成熟参考先纠正切开叶尖，再提交模型；没有缩放成熟株替代幼年阶段。精确任务、版本、种子和整理参数见 [scallion/stages.json](scallion/stages.json)，完整图片提示词与修订见各阶段image-record.json。

| 阶段 | 导出三角 | 高度／宽／深（米） | 形态 |
|---|---:|---|---|
| 苗 | 3055 | .075／.0162／.0266 | 一枚弯钩状细长子叶及较短真叶，共同细基部 |
| 中期 | 5694 | .180／.0703／.0965 | 三片长管叶、一片初生叶和短假茎 |
| 成熟 | 10595 | .3476／.1560／.2800 | 两个相邻基部、七片错落管叶，无花序或洋葱球茎 |

Blender 5.2.2整理时保留原始四边面FBX，按底部假茎切片居中、等比缩放并接地，没有强加旋转、减面、拆叶或变形。三个阶段都保留4K工笔色图、单材质及原始三角数，0零面积面／孤点；诊断开边17／259／84、非流形边19／262／95，少量原生叶尖／接缝开口仍存在，不宣称水密。四向和实景未见大片缺件。成熟高度因.28米最大横展约束略低于请求.36米。土面接触半径分别(.009,.009)、(.009,.009)、(.01927,.01834)米。

小葱使用独立细长叶微风：主摆最多6.5毫米、局部扰动.8毫米，假茎下部28%固定；幼年继续按株高2.5%／.8%限幅，根部受土面约束。保留原画颜色，不套成熟青菜色温，两个画质路径均使用完整模型且禁用额外自动LOD。未调用分件、绑定、付费重贴图或添加粒子。

验证：Blender导出重导入、93项定向资产检查通过；三阶段四向在 `.local/verification/p2-stages/scallion/initial-views/`，实景正反面昼夜与全景／聚焦在 `farm/`，风动开关在 `wind/`。实际两帧风动9898像素变化，关闭后0；已查看所有单体方向、日间三阶段正反面、夜间各阶段代表和聚焦，根部贴合土面。近景画面以接地处为中心，成熟顶部全貌结合单体四向检查。夜景仍暗，后续照明任务未完成。未录新视频、未更新独立包，待用户审美反馈。

重建：Blender运行 `prepare.py -- scallion <sprout|young|mature>`，检查后加 `--install`，再运行项目Godot Import。源图、不可变原模、脱敏任务、blend、GLB与审计按阶段保留；正式落点为 `Game/art/crops/scallion/`。本地索引 `制作留档/03_处理与验证/20260919_小葱三阶段P2重制/README.md`。
