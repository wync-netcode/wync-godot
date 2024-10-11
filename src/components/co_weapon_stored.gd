extends Component
class_name CoWeaponStored
static var label = ECS.add_component()

var weapon_id: StaticData.WEAPON
var bullets_total_left: int
var bullets_magazine_left: int
var time_last_shot: int # to avoid quick switching
var infinite_ammo: bool # for bots
