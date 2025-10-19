using System.Collections.Generic;
using Loreshifter.Game.Sessions;

namespace Loreshifter.Game.Modes.BossBattle;

public static class BossBattleReferenceData
{
    public static WorldDescription WorldLore { get; } = new()
    {
        Overview = "Мир Иллариона переживает эпоху расколотых созвездий, где города-куполы защищают людей от космических бурь.",
        Geography = "Основное поле битвы — кратер, образованный падением осколка звезды, окружённый трещинами с лавой и руинами древнего ордена магов.",
        MagicSystem = "Магия питается от осколков звёзд. Их энергия усиливает арканистов, но переизбыток энергии вызывает искажения реальности.",
        Culture = "Ордены Стражей и Звёздных Провидцев соперничают за контроль над осколками, а свободные герои нанимаются городами для защиты караванов и поселений."
    };

    public static CharacterCreationRules CharacterRules { get; } = new()
    {
        Attributes = new List<CharacterAttributeDefinition>
        {
            new()
            {
                Id = "vitality",
                Name = "Здоровье",
                Description = "Определяет запас жизненных сил и устойчивость к урону. Минимум 3 очка для участия в битве.",
                MinValue = 3,
                MaxValue = 7
            },
            new()
            {
                Id = "might",
                Name = "Сила",
                Description = "Отвечает за физическую мощь, владение оружием ближнего боя и работу с тяжёлым снаряжением.",
                MinValue = 0,
                MaxValue = 7
            },
            new()
            {
                Id = "arcana",
                Name = "Магия",
                Description = "Влияет на контроль звёздной энергии, усиление заклинаний и устойчивость к магическим бурям.",
                MinValue = 0,
                MaxValue = 7
            },
            new()
            {
                Id = "aid",
                Name = "Лечение",
                Description = "Определяет эффективность медицинских приёмов, настоев и умение стабилизировать союзников.",
                MinValue = 0,
                MaxValue = 7
            }
        },
        TotalAssignablePoints = 12,
        Guidance = "Распределите очки между характеристиками. Если значение навыка достигает 5 и выше, ИИ предложит уникальную спецспособность, связанную с этим навыком."
    };

    public static IReadOnlyList<ItemDefinition> Items { get; } = new List<ItemDefinition>
    {
        new()
        {
            Id = "weapon.sword",
            Name = "Стальной меч",
            Category = ItemCategory.Attack,
            Description = "Клинок, выкованный из звёздного металла. Любимый инструмент фронтовых бойцов.",
            Requirements = new List<ItemRequirement>
            {
                new() { AttributeId = "might", RequiredPoints = 3 }
            },
            Effects = new List<ItemEffect>
            {
                new()
                {
                    StatId = "damage",
                    Description = "Режущий урон по одиночной цели.",
                    BaseValue = 18,
                    ScalingAttributeId = "might",
                    ScalingPerPoint = 2,
                    Unit = "ед. урона"
                }
            },
            ConsumedOnUse = false
        },
        new()
        {
            Id = "weapon.staff",
            Name = "Звёздный посох",
            Category = ItemCategory.Attack,
            Description = "Канал для арканической энергии, позволяющий выпускать концентрированные лучи космического пламени.",
            Requirements = new List<ItemRequirement>
            {
                new() { AttributeId = "might", RequiredPoints = 2 },
                new() { AttributeId = "arcana", RequiredPoints = 4 }
            },
            Effects = new List<ItemEffect>
            {
                new()
                {
                    StatId = "damage",
                    Description = "Пробивающий луч звёздного пламени.",
                    BaseValue = 16,
                    ScalingAttributeId = "arcana",
                    ScalingPerPoint = 3,
                    Unit = "ед. урона"
                },
                new()
                {
                    StatId = "overheat",
                    Description = "Риск перегрева канала, снижаемый высокой магией.",
                    BaseValue = 10,
                    ScalingAttributeId = "arcana",
                    ScalingPerPoint = -1.5,
                    Unit = "% вероятности"
                }
            },
            ConsumedOnUse = false
        },
        new()
        {
            Id = "armor.shield",
            Name = "Щит из обсидиановых пластин",
            Category = ItemCategory.Defense,
            Description = "Щит, выкованный из осколков самого титана, поглощает и перенаправляет импульсы.",
            Requirements = new List<ItemRequirement>
            {
                new() { AttributeId = "might", RequiredPoints = 2 }
            },
            Effects = new List<ItemEffect>
            {
                new()
                {
                    StatId = "mitigation",
                    Description = "Процент поглощаемого входящего урона.",
                    BaseValue = 40,
                    ScalingAttributeId = "might",
                    ScalingPerPoint = 4,
                    Unit = "%"
                },
                new()
                {
                    StatId = "max-block",
                    Description = "Максимальный объём урона, который можно удержать за один ход.",
                    BaseValue = 32,
                    ScalingAttributeId = "vitality",
                    ScalingPerPoint = 3,
                    Unit = "ед. урона"
                }
            },
            ConsumedOnUse = false
        },
        new()
        {
            Id = "consumable.bandage",
            Name = "Силовой бинт",
            Category = ItemCategory.Healing,
            Description = "Питательный настой, вплетённый в ткань. Быстро восстанавливает здоровье, но расходуется при применении.",
            Requirements = new List<ItemRequirement>
            {
                new() { AttributeId = "aid", RequiredPoints = 2 }
            },
            Effects = new List<ItemEffect>
            {
                new()
                {
                    StatId = "healing",
                    Description = "Мгновенное восстановление здоровья.",
                    BaseValue = 22,
                    ScalingAttributeId = "aid",
                    ScalingPerPoint = 3,
                    Unit = "ед. здоровья"
                }
            },
            ConsumedOnUse = true
        }
    };

    public static BossProfile BossProfile { get; } = new()
    {
        Name = "Обсидиановый Титан",
        Title = "Страж расколотой звезды",
        Backstory = "Титан был создан орденом Провидцев как защитник городов-купол, но утратил контроль после заражения космической яростью.",
        CombatStyle = "Сочетает подавляющие удары с массовыми волнами пламени, усиливая мощь по мере роста ярости.",
        MaxHealth = 120,
        StartingRage = 10,
        SignatureEquipment = new List<string>
        {
            "Пылающий жезл исполина",
            "Панцирь из сплавленных осколков",
            "Гроздь гравитационных цепей"
        },
        RagePhases = new List<BossRagePhase>
        {
            new()
            {
                RageThreshold = 0,
                Description = "Базовое состояние. Титан анализирует цели и тестирует их защиту.",
                AttackProfile = "Использует одиночные удары кулаками и каменные шипы."
            },
            new()
            {
                RageThreshold = 40,
                Description = "Ярость растёт, титан разогревает панцирь до бела.",
                AttackProfile = "Запускает дуги плазмы, создаёт волны расплавленного стекла."
            },
            new()
            {
                RageThreshold = 75,
                Description = "Режим осады. Титан насыщает арену космическими эманациями.",
                AttackProfile = "Призывает метеоритные удары и гравитационные всплески, требующие координации героев."
            },
            new()
            {
                RageThreshold = 90,
                Description = "Разрушительная кульминация, когда ярость выходит из-под контроля.",
                AttackProfile = "Инициирует катаклизм 'Сердце звезды' — удар, который можно пережить лишь прервав канал."
            }
        }
    };
}