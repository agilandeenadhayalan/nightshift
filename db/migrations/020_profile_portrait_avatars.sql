-- Extend built-in choices without rewriting existing profile selections.
ALTER TABLE profiles DROP CONSTRAINT profiles_avatar_code_check;
ALTER TABLE profiles ADD CONSTRAINT profiles_avatar_code_check
  CHECK (avatar_code IN (
    'moon','star','leaf','wave','male_01','male_02','male_03','male_04',
    'male_05','male_06','male_07','male_08','male_09','male_10','male_11','male_12',
    'male_13','male_14','male_15','male_16','male_17','male_18','male_19','male_20',
    'male_21','male_22','male_23','male_24','male_25','male_26','male_27','male_28',
    'male_29','male_30','female_01','female_02','female_03','female_04','female_05','female_06',
    'female_07','female_08','female_09','female_10','female_11','female_12','female_13','female_14',
    'female_15','female_16','female_17','female_18','female_19','female_20','female_21','female_22',
    'female_23','female_24','female_25','female_26','female_27','female_28','female_29','female_30'
  ));
