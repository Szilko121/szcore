SzCoreJobs = {
    unemployed = {
        label = 'Munkanélküli', type = 'civilian', defaultDuty = false,
        grades = { [0] = { name = 'Munkanélküli', salary = 0, boss = false, permissions = {} } }
    },
    ambulance = {
        label = 'Mentőszolgálat', type = 'ems', defaultDuty = true,
        grades = {
            [0] = { name = 'Gyakornok', salary = 500, boss = false, permissions = { 'ems.basic' } },
            [1] = { name = 'Mentős', salary = 750, boss = false, permissions = { 'ems.basic', 'ems.billing' } },
            [2] = { name = 'Orvos', salary = 1000, boss = false, permissions = { 'ems.basic', 'ems.billing', 'ems.treatment' } },
            [3] = { name = 'Főorvos', salary = 1500, boss = true, permissions = { '*' } }
        }
    },
    police = {
        label = 'Rendőrség', type = 'leo', defaultDuty = true,
        grades = {
            [0] = { name = 'Kadét', salary = 500, boss = false, permissions = { 'police.basic' } },
            [1] = { name = 'Járőr', salary = 750, boss = false, permissions = { 'police.basic', 'police.cuff', 'police.billing' } },
            [2] = { name = 'Őrmester', salary = 1000, boss = false, permissions = { 'police.basic', 'police.cuff', 'police.evidence', 'police.billing', 'police.impound' } },
            [3] = { name = 'Parancsnok', salary = 1500, boss = true, permissions = { '*' } }
        }
    },
    mechanic = {
        label = 'Szerelő', type = 'mechanic', defaultDuty = true,
        grades = {
            [0] = { name = 'Tanuló', salary = 400, boss = false, permissions = { 'mechanic.basic' } },
            [1] = { name = 'Szerelő', salary = 700, boss = false, permissions = { 'mechanic.basic', 'mechanic.billing' } },
            [2] = { name = 'Műhelyvezető', salary = 1100, boss = true, permissions = { '*' } }
        }
    }
}
