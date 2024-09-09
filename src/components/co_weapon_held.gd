extends Component
class_name CoWeaponHeld
static var label = "coweaponheld"

var weapon_id: StaticData.WEAPON
var reloading: bool
var time_started_reloading: int
var once_event_attacking: bool # for animation only
