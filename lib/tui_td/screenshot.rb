# frozen_string_literal: true

require "chunky_png"
require_relative "ansi_utils"

module TUITD
  class Screenshot
    include ANSIUtils

    CELL_W = 8
    CELL_H = 16

    FONT = [
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,  # space (32)
      0x00, 0x00, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x00, 0x18, 0x18, 0x00, 0x00, 0x00, 0x00,  # ! (33)
      0x00, 0x66, 0x66, 0x66, 0x66, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,  # " (34)
      0x00, 0x00, 0x6c, 0x6c, 0xfe, 0x6c, 0x6c, 0x6c, 0x6c, 0xfe, 0x6c, 0x6c, 0x00, 0x00, 0x00, 0x00,  # # (35)
      0x00, 0x10, 0x7e, 0xd0, 0xd0, 0xd0, 0x7c, 0x16, 0x16, 0x16, 0x16, 0xfc, 0x10, 0x00, 0x00, 0x00,  # $ (36)
      0x00, 0x00, 0x06, 0x66, 0x6c, 0x0c, 0x18, 0x18, 0x30, 0x36, 0x66, 0x60, 0x00, 0x00, 0x00, 0x00,  # % (37)
      0x00, 0x00, 0x38, 0x6c, 0x6c, 0x6c, 0x38, 0x70, 0xda, 0xcc, 0xcc, 0x7a, 0x00, 0x00, 0x00, 0x00,  # & (38)
      0x00, 0x18, 0x18, 0x18, 0x18, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,  # ' (39)
      0x00, 0x0e, 0x18, 0x30, 0x30, 0x60, 0x60, 0x60, 0x60, 0x30, 0x30, 0x18, 0x0e, 0x00, 0x00, 0x00,  # ( (40)
      0x00, 0x70, 0x18, 0x0c, 0x0c, 0x06, 0x06, 0x06, 0x06, 0x0c, 0x0c, 0x18, 0x70, 0x00, 0x00, 0x00,  # ) (41)
      0x00, 0x00, 0x00, 0x00, 0x66, 0x3c, 0x18, 0xff, 0x18, 0x3c, 0x66, 0x00, 0x00, 0x00, 0x00, 0x00,  # * (42)
      0x00, 0x00, 0x00, 0x00, 0x00, 0x18, 0x18, 0x7e, 0x18, 0x18, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,  # + (43)
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x18, 0x18, 0x30, 0x00, 0x00, 0x00,  # , (44)
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x7e, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,  # - (45)
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x18, 0x18, 0x00, 0x00, 0x00, 0x00,  # . (46)
      0x00, 0x06, 0x06, 0x0c, 0x0c, 0x18, 0x18, 0x30, 0x30, 0x60, 0x60, 0xc0, 0xc0, 0x00, 0x00, 0x00,  # / (47)
      0x00, 0x00, 0x7c, 0xc6, 0xc6, 0xce, 0xde, 0xf6, 0xe6, 0xc6, 0xc6, 0x7c, 0x00, 0x00, 0x00, 0x00,  # 0 (48)
      0x00, 0x00, 0x18, 0x38, 0x78, 0x58, 0x18, 0x18, 0x18, 0x18, 0x18, 0x7e, 0x00, 0x00, 0x00, 0x00,  # 1 (49)
      0x00, 0x00, 0x7c, 0xc6, 0x06, 0x06, 0x0c, 0x18, 0x30, 0x60, 0xc6, 0xfe, 0x00, 0x00, 0x00, 0x00,  # 2 (50)
      0x00, 0x00, 0x7c, 0xc6, 0x06, 0x06, 0x3c, 0x06, 0x06, 0x06, 0xc6, 0x7c, 0x00, 0x00, 0x00, 0x00,  # 3 (51)
      0x00, 0x00, 0xc0, 0xc0, 0xcc, 0xcc, 0xcc, 0xcc, 0xfe, 0x0c, 0x0c, 0x0c, 0x00, 0x00, 0x00, 0x00,  # 4 (52)
      0x00, 0x00, 0xfe, 0xc6, 0xc0, 0xc0, 0xfc, 0x06, 0x06, 0x06, 0xc6, 0x7c, 0x00, 0x00, 0x00, 0x00,  # 5 (53)
      0x00, 0x00, 0x7c, 0xc6, 0xc0, 0xc0, 0xfc, 0xc6, 0xc6, 0xc6, 0xc6, 0x7c, 0x00, 0x00, 0x00, 0x00,  # 6 (54)
      0x00, 0x00, 0xfe, 0xc6, 0x06, 0x06, 0x0c, 0x18, 0x30, 0x30, 0x30, 0x30, 0x00, 0x00, 0x00, 0x00,  # 7 (55)
      0x00, 0x00, 0x7c, 0xc6, 0xc6, 0xc6, 0x7c, 0xc6, 0xc6, 0xc6, 0xc6, 0x7c, 0x00, 0x00, 0x00, 0x00,  # 8 (56)
      0x00, 0x00, 0x7c, 0xc6, 0xc6, 0xc6, 0xc6, 0x7e, 0x06, 0x06, 0xc6, 0x7c, 0x00, 0x00, 0x00, 0x00,  # 9 (57)
      0x00, 0x00, 0x00, 0x00, 0x00, 0x18, 0x18, 0x00, 0x00, 0x00, 0x18, 0x18, 0x00, 0x00, 0x00, 0x00,  # : (58)
      0x00, 0x00, 0x00, 0x00, 0x00, 0x18, 0x18, 0x00, 0x00, 0x00, 0x18, 0x18, 0x30, 0x00, 0x00, 0x00,  # ; (59)
      0x00, 0x00, 0x06, 0x0c, 0x18, 0x30, 0x60, 0x60, 0x30, 0x18, 0x0c, 0x06, 0x00, 0x00, 0x00, 0x00,  # < (60)
      0x00, 0x00, 0x00, 0x00, 0x00, 0x7e, 0x00, 0x00, 0x7e, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,  # = (61)
      0x00, 0x00, 0x60, 0x30, 0x18, 0x0c, 0x06, 0x06, 0x0c, 0x18, 0x30, 0x60, 0x00, 0x00, 0x00, 0x00,  # > (62)
      0x00, 0x00, 0x7c, 0xc6, 0x06, 0x0c, 0x18, 0x30, 0x30, 0x00, 0x30, 0x30, 0x00, 0x00, 0x00, 0x00,  # ? (63)
      0x00, 0x00, 0x00, 0x7c, 0xc2, 0xda, 0xda, 0xda, 0xda, 0xde, 0xc0, 0x7c, 0x00, 0x00, 0x00, 0x00,  # @ (64)
      0x00, 0x00, 0x7c, 0xc6, 0xc6, 0xc6, 0xfe, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6, 0x00, 0x00, 0x00, 0x00,  # A (65)
      0x00, 0x00, 0xfc, 0xc6, 0xc6, 0xc6, 0xfc, 0xc6, 0xc6, 0xc6, 0xc6, 0xfc, 0x00, 0x00, 0x00, 0x00,  # B (66)
      0x00, 0x00, 0x7e, 0xc0, 0xc0, 0xc0, 0xc0, 0xc0, 0xc0, 0xc0, 0xc0, 0x7e, 0x00, 0x00, 0x00, 0x00,  # C (67)
      0x00, 0x00, 0xfc, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6, 0xfc, 0x00, 0x00, 0x00, 0x00,  # D (68)
      0x00, 0x00, 0x7e, 0xc0, 0xc0, 0xc0, 0xf8, 0xc0, 0xc0, 0xc0, 0xc0, 0x7e, 0x00, 0x00, 0x00, 0x00,  # E (69)
      0x00, 0x00, 0x7e, 0xc0, 0xc0, 0xc0, 0xf8, 0xc0, 0xc0, 0xc0, 0xc0, 0xc0, 0x00, 0x00, 0x00, 0x00,  # F (70)
      0x00, 0x00, 0x7e, 0xc0, 0xc0, 0xc0, 0xde, 0xc6, 0xc6, 0xc6, 0xc6, 0x7e, 0x00, 0x00, 0x00, 0x00,  # G (71)
      0x00, 0x00, 0xc6, 0xc6, 0xc6, 0xc6, 0xfe, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6, 0x00, 0x00, 0x00, 0x00,  # H (72)
      0x00, 0x00, 0x7e, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x7e, 0x00, 0x00, 0x00, 0x00,  # I (73)
      0x00, 0x00, 0x7e, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0xf0, 0x00, 0x00, 0x00, 0x00,  # J (74)
      0x00, 0x00, 0xc6, 0xc6, 0xc6, 0xcc, 0xf8, 0xcc, 0xc6, 0xc6, 0xc6, 0xc6, 0x00, 0x00, 0x00, 0x00,  # K (75)
      0x00, 0x00, 0xc0, 0xc0, 0xc0, 0xc0, 0xc0, 0xc0, 0xc0, 0xc0, 0xc0, 0x7e, 0x00, 0x00, 0x00, 0x00,  # L (76)
      0x00, 0x00, 0xc6, 0xee, 0xfe, 0xd6, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6, 0x00, 0x00, 0x00, 0x00,  # M (77)
      0x00, 0x00, 0xc6, 0xc6, 0xe6, 0xe6, 0xd6, 0xd6, 0xce, 0xce, 0xc6, 0xc6, 0x00, 0x00, 0x00, 0x00,  # N (78)
      0x00, 0x00, 0x7c, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6, 0x7c, 0x00, 0x00, 0x00, 0x00,  # O (79)
      0x00, 0x00, 0xfc, 0xc6, 0xc6, 0xc6, 0xfc, 0xc0, 0xc0, 0xc0, 0xc0, 0xc0, 0x00, 0x00, 0x00, 0x00,  # P (80)
      0x00, 0x00, 0x7c, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6, 0xd6, 0xd6, 0x7c, 0x18, 0x0c, 0x00, 0x00,  # Q (81)
      0x00, 0x00, 0xfc, 0xc6, 0xc6, 0xc6, 0xfc, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6, 0x00, 0x00, 0x00, 0x00,  # R (82)
      0x00, 0x00, 0x7e, 0xc0, 0xc0, 0xc0, 0x7c, 0x06, 0x06, 0x06, 0x06, 0xfc, 0x00, 0x00, 0x00, 0x00,  # S (83)
      0x00, 0x00, 0xff, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x00, 0x00, 0x00, 0x00,  # T (84)
      0x00, 0x00, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6, 0x7e, 0x00, 0x00, 0x00, 0x00,  # U (85)
      0x00, 0x00, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6, 0x6c, 0x38, 0x10, 0x00, 0x00, 0x00, 0x00,  # V (86)
      0x00, 0x00, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6, 0xd6, 0xfe, 0xee, 0xc6, 0x00, 0x00, 0x00, 0x00,  # W (87)
      0x00, 0x00, 0xc6, 0xc6, 0xc6, 0x6c, 0x38, 0x6c, 0xc6, 0xc6, 0xc6, 0xc6, 0x00, 0x00, 0x00, 0x00,  # X (88)
      0x00, 0x00, 0xc6, 0xc6, 0xc6, 0xc6, 0x7e, 0x06, 0x06, 0x06, 0x06, 0xfc, 0x00, 0x00, 0x00, 0x00,  # Y (89)
      0x00, 0x00, 0xfe, 0x06, 0x06, 0x0c, 0x18, 0x30, 0x60, 0xc0, 0xc0, 0xfe, 0x00, 0x00, 0x00, 0x00,  # Z (90)
      0x00, 0x3e, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30, 0x3e, 0x00, 0x00, 0x00,  # [ (91)
      0x00, 0xc0, 0xc0, 0x60, 0x60, 0x30, 0x30, 0x18, 0x18, 0x0c, 0x0c, 0x06, 0x06, 0x00, 0x00, 0x00,  # \ (92)
      0x00, 0x7c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x7c, 0x00, 0x00, 0x00,  # ] (93)
      0x00, 0x10, 0x38, 0x6c, 0xc6, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,  # ^ (94)
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xfe, 0x00,  # _ (95)
      0x00, 0x30, 0x18, 0x0c, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,  # ` (96)
      0x00, 0x00, 0x00, 0x00, 0x00, 0x7c, 0x06, 0x7e, 0xc6, 0xc6, 0xc6, 0x7e, 0x00, 0x00, 0x00, 0x00,  # a (97)
      0x00, 0x00, 0xc0, 0xc0, 0xc0, 0xfc, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6, 0xfc, 0x00, 0x00, 0x00, 0x00,  # b (98)
      0x00, 0x00, 0x00, 0x00, 0x00, 0x7e, 0xc0, 0xc0, 0xc0, 0xc0, 0xc0, 0x7e, 0x00, 0x00, 0x00, 0x00,  # c (99)
      0x00, 0x00, 0x06, 0x06, 0x06, 0x7e, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6, 0x7e, 0x00, 0x00, 0x00, 0x00,  # d (100)
      0x00, 0x00, 0x00, 0x00, 0x00, 0x7e, 0xc6, 0xc6, 0xfe, 0xc0, 0xc0, 0x7e, 0x00, 0x00, 0x00, 0x00,  # e (101)
      0x00, 0x00, 0x1e, 0x30, 0x30, 0x30, 0x7c, 0x30, 0x30, 0x30, 0x30, 0x30, 0x00, 0x00, 0x00, 0x00,  # f (102)
      0x00, 0x00, 0x00, 0x00, 0x00, 0x7e, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6, 0x7c, 0x06, 0x06, 0xfc, 0x00,  # g (103)
      0x00, 0x00, 0xc0, 0xc0, 0xc0, 0xfc, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6, 0x00, 0x00, 0x00, 0x00,  # h (104)
      0x00, 0x00, 0x18, 0x18, 0x00, 0x38, 0x18, 0x18, 0x18, 0x18, 0x18, 0x1c, 0x00, 0x00, 0x00, 0x00,  # i (105)
      0x00, 0x00, 0x18, 0x18, 0x00, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x70, 0x00,  # j (106)
      0x00, 0x00, 0xc0, 0xc0, 0xc0, 0xcc, 0xd8, 0xf0, 0xf0, 0xd8, 0xcc, 0xc6, 0x00, 0x00, 0x00, 0x00,  # k (107)
      0x00, 0x00, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30, 0x1c, 0x00, 0x00, 0x00, 0x00,  # l (108)
      0x00, 0x00, 0x00, 0x00, 0x00, 0xec, 0xd6, 0xd6, 0xd6, 0xd6, 0xc6, 0xc6, 0x00, 0x00, 0x00, 0x00,  # m (109)
      0x00, 0x00, 0x00, 0x00, 0x00, 0xfc, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6, 0x00, 0x00, 0x00, 0x00,  # n (110)
      0x00, 0x00, 0x00, 0x00, 0x00, 0x7c, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6, 0x7c, 0x00, 0x00, 0x00, 0x00,  # o (111)
      0x00, 0x00, 0x00, 0x00, 0x00, 0xfc, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6, 0xfc, 0xc0, 0xc0, 0xc0, 0x00,  # p (112)
      0x00, 0x00, 0x00, 0x00, 0x00, 0x7e, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6, 0x7e, 0x06, 0x06, 0x06, 0x00,  # q (113)
      0x00, 0x00, 0x00, 0x00, 0x00, 0x7e, 0xc6, 0xc0, 0xc0, 0xc0, 0xc0, 0xc0, 0x00, 0x00, 0x00, 0x00,  # r (114)
      0x00, 0x00, 0x00, 0x00, 0x00, 0x7e, 0xc0, 0xc0, 0x7c, 0x06, 0x06, 0xfc, 0x00, 0x00, 0x00, 0x00,  # s (115)
      0x00, 0x00, 0x30, 0x30, 0x30, 0x7c, 0x30, 0x30, 0x30, 0x30, 0x30, 0x1e, 0x00, 0x00, 0x00, 0x00,  # t (116)
      0x00, 0x00, 0x00, 0x00, 0x00, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6, 0x7e, 0x00, 0x00, 0x00, 0x00,  # u (117)
      0x00, 0x00, 0x00, 0x00, 0x00, 0xc6, 0xc6, 0xc6, 0xc6, 0x6c, 0x38, 0x10, 0x00, 0x00, 0x00, 0x00,  # v (118)
      0x00, 0x00, 0x00, 0x00, 0x00, 0xc6, 0xc6, 0xd6, 0xd6, 0xd6, 0xd6, 0x6e, 0x00, 0x00, 0x00, 0x00,  # w (119)
      0x00, 0x00, 0x00, 0x00, 0x00, 0xc6, 0x6c, 0x38, 0x38, 0x6c, 0xc6, 0xc6, 0x00, 0x00, 0x00, 0x00,  # x (120)
      0x00, 0x00, 0x00, 0x00, 0x00, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6, 0x7e, 0x06, 0x06, 0xfc, 0x00,  # y (121)
      0x00, 0x00, 0x00, 0x00, 0x00, 0xfe, 0x06, 0x0c, 0x18, 0x30, 0x60, 0xfe, 0x00, 0x00, 0x00, 0x00,  # z (122)
      0x00, 0x0e, 0x18, 0x18, 0x18, 0x18, 0x70, 0x70, 0x18, 0x18, 0x18, 0x18, 0x0e, 0x00, 0x00, 0x00,  # { (123)
      0x00, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x00, 0x00, 0x00,  # | (124)
      0x00, 0x70, 0x18, 0x18, 0x18, 0x18, 0x0e, 0x0e, 0x18, 0x18, 0x18, 0x18, 0x70, 0x00, 0x00, 0x00,  # } (125)
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x32, 0x7e, 0x4c, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,  # ~ (126)
    ].freeze
    BOX_CHARS = {
      # horizontal
      "─" => [false, false, true, true, :light],
      "━" => [false, false, true, true, :heavy],
      "═" => [false, false, true, true, :double],
      # vertical
      "│" => [true, true, false, false, :light],
      "┃" => [true, true, false, false, :heavy],
      "║" => [true, true, false, false, :double],
      # corners
      "╭" => [false, true, false, true, :light_rounded],
      "╮" => [false, true, true, false, :light_rounded],
      "╯" => [true, false, true, false, :light_rounded],
      "╰" => [true, false, false, true, :light_rounded],
      "┌" => [false, true, false, true, :light],
      "┍" => [false, true, false, true, :light],
      "┎" => [false, true, false, true, :light],
      "┏" => [false, true, false, true, :heavy],
      "┐" => [false, true, true, false, :light],
      "┑" => [false, true, true, false, :light],
      "┒" => [false, true, true, false, :light],
      "┓" => [false, true, true, false, :heavy],
      "└" => [true, false, false, true, :light],
      "┖" => [true, false, false, true, :light],
      "┗" => [true, false, false, true, :heavy],
      "┘" => [true, false, true, false, :light],
      "┙" => [true, false, true, false, :light],
      "┚" => [true, false, true, false, :light],
      "┛" => [true, false, true, false, :heavy],
      # double corners
      "╔" => [false, true, false, true, :double],
      "╗" => [false, true, true, false, :double],
      "╚" => [true, false, false, true, :double],
      "╝" => [true, false, true, false, :double],
      # T-junctions
      "├" => [true, true, false, true, :light],
      "┣" => [true, true, false, true, :heavy],
      "┤" => [true, true, true, false, :light],
      "┫" => [true, true, true, false, :heavy],
      "┬" => [false, true, true, true, :light],
      "┳" => [false, true, true, true, :heavy],
      "┴" => [true, false, true, true, :light],
      "┻" => [true, false, true, true, :heavy],
      # double T-junctions
      "╠" => [true, true, false, true, :double],
      "╣" => [true, true, true, false, :double],
      "╦" => [false, true, true, true, :double],
      "╩" => [true, false, true, true, :double],
      # crosses
      "┼" => [true, true, true, true, :light],
      "╋" => [true, true, true, true, :heavy],
      "╬" => [true, true, true, true, :double],
      # single lines (ends)
      "╴" => [false, false, true, false, :light],
      "╵" => [true, false, false, false, :light],
      "╶" => [false, false, false, true, :light],
      "╷" => [false, true, false, false, :light],
      "╸" => [false, false, true, false, :heavy],
      "╹" => [true, false, false, false, :heavy],
      "╺" => [false, false, false, true, :heavy],
      "╻" => [false, true, false, false, :heavy],
      # mixed corners/junctions
      "┿" => [true, true, true, true, :light],
      "╀" => [true, true, true, true, :light],
      "╁" => [true, true, true, true, :light],
      "╂" => [true, true, true, true, :light],
      "╃" => [true, true, true, true, :heavy],
      "╄" => [true, true, true, true, :heavy],
      "╅" => [true, true, true, true, :heavy],
      "╆" => [true, true, true, true, :heavy],
      "╇" => [true, true, true, true, :heavy],
      "╈" => [true, true, true, true, :heavy],
      "╉" => [true, true, true, true, :heavy],
      "╊" => [true, true, true, true, :heavy],
      "╒" => [false, true, false, true, :double],
      "╓" => [false, true, false, true, :double],
      "╕" => [false, true, true, false, :double],
      "╖" => [false, true, true, false, :double],
      "╘" => [true, false, false, true, :double],
      "╙" => [true, false, false, true, :double],
      "╛" => [true, false, true, false, :double],
      "╜" => [true, false, true, false, :double],
      "╞" => [true, true, false, true, :double],
      "╟" => [true, true, false, true, :double],
      "╡" => [true, true, true, false, :double],
      "╢" => [true, true, true, false, :double],
      "╤" => [false, true, true, true, :double],
      "╥" => [false, true, true, true, :double],
      "╧" => [true, false, true, true, :double],
      "╨" => [true, false, true, true, :double],
      "╪" => [true, true, true, true, :double],
      "╫" => [true, true, true, true, :double]
    }.freeze

    private_constant :FONT

    def initialize(state)
      @state = state
      @rows = _dig(state, :size, :rows) || 40
      @cols = _dig(state, :size, :cols) || 120
      @grid = state[:rows] || state["rows"] || []
    end

    def render(output_path)
      width = @cols * CELL_W
      height = @rows * CELL_H
      image = ChunkyPNG::Image.new(width, height, ChunkyPNG::Color::BLACK)

      @grid.each_with_index do |row, ri|
        next unless row
        row.each_with_index do |cell, ci|
          next unless cell
          render_cell(image, ri, ci, cell)
        end
      end

      draw_cursor(image)

      image.save(output_path)
      output_path
    end

    private

    def render_cell(image, ri, ci, cell)
      char = cell[:char] || cell["char"] || " "
      fg = cell[:fg] || cell["fg"] || "default"
      bg = cell[:bg] || cell["bg"] || "default"
      bold = cell[:bold] || cell["bold"] || false
      italic = cell[:italic] || cell["italic"] || false
      underline = cell[:underline] || cell["underline"] || false

      fg_rgb = resolve_color(fg, DEFAULT_FG)
      bg_rgb = resolve_color(bg, DEFAULT_BG)

      px = ci * CELL_W
      py = ri * CELL_H

      fill_rect(image, px, py, CELL_W, CELL_H, bg_rgb)

      if box_drawing?(char)
        draw_box_character(image, px, py, char, fg_rgb)
        draw_underline(image, px, py, CELL_W, fg_rgb) if underline
        return
      end

      char_ord = char.ord
      if char_ord == 10095 # '❯'
        draw_chevron(image, px, py, fg_rgb)
        draw_underline(image, px, py, CELL_W, fg_rgb) if underline
        return
      elsif char_ord == 9210 || char_ord == 9679 # '⏺' or '●'
        draw_circle(image, px, py, fg_rgb)
        draw_underline(image, px, py, CELL_W, fg_rgb) if underline
        return
      elsif char_ord >= 0x2800 && char_ord <= 0x28ff # Braille spinner
        draw_braille(image, px, py, char, fg_rgb)
        draw_underline(image, px, py, CELL_W, fg_rgb) if underline
        return
      elsif char_ord == 0x2580 # '▀'
        fill_rect(image, px, py, CELL_W, 8, fg_rgb)
        draw_underline(image, px, py, CELL_W, fg_rgb) if underline
        return
      elsif char_ord == 0x2584 # '▄'
        fill_rect(image, px, py + 8, CELL_W, 8, fg_rgb)
        draw_underline(image, px, py, CELL_W, fg_rgb) if underline
        return
      elsif char_ord == 0x2588 # '█'
        fill_rect(image, px, py, CELL_W, CELL_H, fg_rgb)
        draw_underline(image, px, py, CELL_W, fg_rgb) if underline
        return
      elsif char_ord == 0x25B2 # '▲'
        draw_up_triangle(image, px, py, fg_rgb)
        draw_underline(image, px, py, CELL_W, fg_rgb) if underline
        return
      elsif char_ord == 0x25BC # '▼'
        draw_down_triangle(image, px, py, fg_rgb)
        draw_underline(image, px, py, CELL_W, fg_rgb) if underline
        return
      elsif char_ord == 0x2713 # '✓'
        draw_checkmark(image, px, py, fg_rgb)
        draw_underline(image, px, py, CELL_W, fg_rgb) if underline
        return
      elsif char_ord == 0x2717 # '✗'
        draw_ballot_x(image, px, py, fg_rgb)
        draw_underline(image, px, py, CELL_W, fg_rgb) if underline
        return
      elsif char_ord == 0x2191 # '↑'
        draw_up_arrow(image, px, py, fg_rgb)
        draw_underline(image, px, py, CELL_W, fg_rgb) if underline
        return
      elsif char_ord == 0x2192 # '→'
        draw_right_arrow(image, px, py, fg_rgb)
        draw_underline(image, px, py, CELL_W, fg_rgb) if underline
        return
      elsif char_ord == 0x2193 # '↓'
        draw_down_arrow(image, px, py, fg_rgb)
        draw_underline(image, px, py, CELL_W, fg_rgb) if underline
        return
      elsif char_ord == 0x2699 # '⚙'
        draw_gear(image, px, py, fg_rgb)
        draw_underline(image, px, py, CELL_W, fg_rgb) if underline
        return
      elsif char_ord == 0x26A0 # '⚠'
        draw_warning(image, px, py, fg_rgb)
        draw_underline(image, px, py, CELL_W, fg_rgb) if underline
        return
      elsif char_ord == 0x2026 # '…'
        draw_ellipsis(image, px, py, fg_rgb)
        draw_underline(image, px, py, CELL_W, fg_rgb) if underline
        return
      elsif char_ord == 0x2014 # '—'
        (px..(px + 7)).each { |x| image[x, py + 8] = ChunkyPNG::Color.rgb(*fg_rgb) }
        draw_underline(image, px, py, CELL_W, fg_rgb) if underline
        return
      elsif char_ord == 0x2190 # '←'
        draw_left_arrow(image, px, py, fg_rgb)
        draw_underline(image, px, py, CELL_W, fg_rgb) if underline
        return
      elsif char_ord == 0x258C # '▌'
        draw_left_half_block(image, px, py, fg_rgb)
        draw_underline(image, px, py, CELL_W, fg_rgb) if underline
        return
      elsif char_ord == 0x2590 # '▐'
        draw_right_half_block(image, px, py, fg_rgb)
        draw_underline(image, px, py, CELL_W, fg_rgb) if underline
        return
      elsif char_ord == 0x2610 # '☐'
        draw_empty_checkbox(image, px, py, fg_rgb)
        draw_underline(image, px, py, CELL_W, fg_rgb) if underline
        return
      elsif char_ord == 0x2611 # '☑'
        draw_checked_checkbox(image, px, py, fg_rgb)
        draw_underline(image, px, py, CELL_W, fg_rgb) if underline
        return
      elsif char_ord == 0x2612 # '☒'
        draw_x_checkbox(image, px, py, fg_rgb)
        draw_underline(image, px, py, CELL_W, fg_rgb) if underline
        return
      elsif char_ord == 0x2139 # 'ℹ'
        draw_info_symbol(image, px, py, fg_rgb)
        draw_underline(image, px, py, CELL_W, fg_rgb) if underline
        return
      elsif char_ord == 0x2716 # '✖'
        draw_heavy_x(image, px, py, fg_rgb)
        draw_underline(image, px, py, CELL_W, fg_rgb) if underline
        return
      end

      return if char == " " || char_ord < 32 || char_ord > 126

      rows_data = glyph_rows(char)
      return unless rows_data

      draw_glyph(image, px, py, rows_data, fg_rgb, bold: bold, italic: italic)

      draw_underline(image, px, py, CELL_W, fg_rgb) if underline
    end

    def fill_rect(image, x, y, w, h, rgb)
      color = ChunkyPNG::Color.rgb(*rgb)
      h.times do |dy|
        w.times do |dx|
          image[x + dx, y + dy] = color
        end
      end
    end

    def glyph_rows(char)
      idx = (char.ord - 32) * 16
      return nil if idx < 0 || idx + 15 >= FONT.length

      FONT[idx, 16]
    end

    def draw_glyph(image, px, py, rows, fg_rgb, bold:, italic:)
      color = ChunkyPNG::Color.rgb(*fg_rgb)

      rows.each_with_index do |byte, dy|
        next if byte == 0

        slant = italic ? dy / 8 : 0

        8.times do |dx|
          next unless (byte >> (7 - dx)) & 1 == 1

          image[px + dx + slant, py + dy] = color
          image[px + dx + slant + 1, py + dy] = color if bold
        end
      end
    end

    def draw_underline(image, px, py, w, fg_rgb)
      color = ChunkyPNG::Color.rgb(*fg_rgb)
      y = py + CELL_H - 2
      w.times { |dx| image[px + dx, y] = color }
    end

    def box_drawing?(char)
      char_ord = char.ord
      char_ord >= 0x2500 && char_ord <= 0x257F
    end

    def draw_box_character(image, px, py, char, fg_rgb)
      config = BOX_CHARS[char]

      unless config
        char_ord = char.ord
        if [0x2500, 0x2501, 0x2504, 0x2505, 0x2508, 0x2509, 0x254c, 0x254d, 0x2550].include?(char_ord)
          style = [0x2501, 0x2505, 0x2509, 0x254d].include?(char_ord) ? :heavy : (char_ord == 0x2550 ? :double : :light)
          config = [false, false, true, true, style]
        elsif [0x2502, 0x2503, 0x2506, 0x2507, 0x250a, 0x250b, 0x254e, 0x254f, 0x2551].include?(char_ord)
          style = [0x2503, 0x2507, 0x250b, 0x254f].include?(char_ord) ? :heavy : (char_ord == 0x2551 ? :double : :light)
          config = [true, true, false, false, style]
        else
          config = [true, true, true, true, :light]
        end
      end

      up, down, left, right, style = config
      cx = px + 4
      cy = py + 8

      color = ChunkyPNG::Color.rgb(*fg_rgb)

      if style == :double
        if left
          (px..(cx + 2)).each { |x| image[x, py + 6] = color }
          (px..(cx + 2)).each { |x| image[x, py + 10] = color }
        end
        if right
          ((cx - 2)..(px + 7)).each { |x| image[x, py + 6] = color }
          ((cx - 2)..(px + 10)).each { |x| image[x, py + 10] = color }
        end
        if up
          (py..(cy + 2)).each { |y| image[px + 2, y] = color }
          (py..(cy + 2)).each { |y| image[px + 6, y] = color }
        end
        if down
          ((cy - 2)..(py + 15)).each { |y| image[px + 2, y] = color }
          ((cy - 2)..(py + 15)).each { |y| image[px + 6, y] = color }
        end
      elsif style == :heavy
        if left
          (px..cx).each do |x|
            image[x, cy - 1] = color
            image[x, cy] = color
            image[x, cy + 1] = color
          end
        end
        if right
          (cx..(px + 7)).each do |x|
            image[x, cy - 1] = color
            image[x, cy] = color
            image[x, cy + 1] = color
          end
        end
        if up
          (py..cy).each do |y|
            image[cx - 1, y] = color
            image[cx, y] = color
            image[cx + 1, y] = color
          end
        end
        if down
          (cy..(py + 15)).each do |y|
            image[cx - 1, y] = color
            image[cx, y] = color
            image[cx + 1, y] = color
          end
        end
      elsif style == :light_rounded
        case char
        when "╭"
          (px + 5..px + 7).each { |x| image[x, py + 8] = color }
          (py + 10..py + 15).each { |y| image[px + 4, y] = color }
          image[px + 4, py + 9] = color
          image[px + 5, py + 9] = color
        when "╮"
          (px..px + 3).each { |x| image[x, py + 8] = color }
          (py + 10..py + 15).each { |y| image[px + 4, y] = color }
          image[px + 4, py + 9] = color
          image[px + 3, py + 9] = color
        when "╯"
          (px..px + 3).each { |x| image[x, py + 8] = color }
          (py..py + 6).each { |y| image[px + 4, y] = color }
          image[px + 4, py + 7] = color
          image[px + 3, py + 7] = color
        when "╰"
          (px + 5..px + 7).each { |x| image[x, py + 8] = color }
          (py..py + 6).each { |y| image[px + 4, y] = color }
          image[px + 4, py + 7] = color
          image[px + 5, py + 7] = color
        end
      else # :light
        if left
          (px..cx).each { |x| image[x, cy] = color }
        end
        if right
          (cx..(px + 7)).each { |x| image[x, cy] = color }
        end
        if up
          (py..cy).each { |y| image[cx, y] = color }
        end
        if down
          (cy..(py + 15)).each { |y| image[cx, y] = color }
        end
      end
    end

    def draw_cursor(image)
      cursor_info = @state[:cursor] || @state["cursor"] || {}
      cursor_vis = @state[:cursor_visible]
      cursor_vis = cursor_info[:visible] if cursor_vis.nil?
      cursor_vis = cursor_info["visible"] if cursor_vis.nil?
      cursor_vis = false if cursor_vis.nil? # default invisible

      return unless cursor_vis

      ri = cursor_info[:row] || cursor_info["row"] || 0
      ci = cursor_info[:col] || cursor_info["col"] || 0

      return if ri < 0 || ri >= @rows || ci < 0 || ci >= @cols

      style_val = @state[:cursor_style] || cursor_info[:style] || cursor_info["style"] || 1

      px = ci * CELL_W
      py = ri * CELL_H

      color_rgb = [255, 255, 255] # Weiß standardmäßig
      color = ChunkyPNG::Color.rgb(*color_rgb)

      case style_val
      when 1, 2 # Blinking Block oder Steady Block
        CELL_H.times do |dy|
          CELL_W.times do |dx|
            x = px + dx
            y = py + dy
            next if x >= image.width || y >= image.height
            original_color = image[x, y]
            r = 255 - ChunkyPNG::Color.r(original_color)
            g = 255 - ChunkyPNG::Color.g(original_color)
            b = 255 - ChunkyPNG::Color.b(original_color)
            image[x, y] = ChunkyPNG::Color.rgb(r, g, b)
          end
        end
      when 3, 4 # Underline
        2.times do |h_offset|
          y = py + CELL_H - 1 - h_offset
          next if y >= image.height
          CELL_W.times do |dx|
            x = px + dx
            next if x >= image.width
            image[x, y] = color
          end
        end
      when 5, 6 # Bar
        2.times do |w_offset|
          x = px + w_offset
          next if x >= image.width
          CELL_H.times do |dy|
            y = py + dy
            next if y >= image.height
            image[x, y] = color
          end
        end
      end
    end

    def draw_chevron(image, px, py, fg_rgb)
      color = ChunkyPNG::Color.rgb(*fg_rgb)
      (0..3).each do |i|
        image[px + 2 + i, py + 4 + i] = color
        image[px + 3 + i, py + 4 + i] = color # bold/thick chevron
        
        image[px + 5 - i, py + 8 + i] = color
        image[px + 6 - i, py + 8 + i] = color # bold/thick chevron
      end
    end

    def draw_circle(image, px, py, fg_rgb)
      color = ChunkyPNG::Color.rgb(*fg_rgb)
      cx = px + 4
      cy = py + 8
      (-3..3).each do |dy|
        r_width = case dy.abs
                  when 3 then 1
                  when 2 then 2
                  else 3
                  end
        (-r_width..r_width).each do |dx|
          x = cx + dx
          y = cy + dy
          next if x < px || x >= px + CELL_W || y < py || y >= py + CELL_H
          image[x, y] = color
        end
      end
    end

    def draw_braille(image, px, py, char, fg_rgb)
      color = ChunkyPNG::Color.rgb(*fg_rgb)
      mask = char.ord - 0x2800
      dot_coords = [
        [2, 3],  # Dot 1
        [2, 6],  # Dot 2
        [2, 9],  # Dot 3
        [5, 3],  # Dot 4
        [5, 6],  # Dot 5
        [5, 9],  # Dot 6
        [2, 12], # Dot 7
        [5, 12]  # Dot 8
      ]
      dot_coords.each_with_index do |(dx, dy), idx|
        if (mask & (1 << idx)) != 0
          2.times do |ddy|
            2.times do |ddx|
              x = px + dx + ddx
              y = py + dy + ddy
              next if x >= image.width || y >= image.height
              image[x, y] = color
            end
          end
        end
      end
    end

    def draw_up_triangle(image, px, py, fg_rgb)
      color = ChunkyPNG::Color.rgb(*fg_rgb)
      (5..8).each do |dy|
        width = dy - 5
        (4 - width..4 + width).each do |dx|
          image[px + dx, py + dy] = color
        end
      end
    end

    def draw_down_triangle(image, px, py, fg_rgb)
      color = ChunkyPNG::Color.rgb(*fg_rgb)
      (5..8).each do |dy|
        width = 8 - dy
        (4 - width..4 + width).each do |dx|
          image[px + dx, py + dy] = color
        end
      end
    end

    def draw_checkmark(image, px, py, fg_rgb)
      color = ChunkyPNG::Color.rgb(*fg_rgb)
      image[px + 2, py + 8] = color
      image[px + 3, py + 9] = color
      image[px + 4, py + 10] = color
      image[px + 5, py + 8] = color
      image[px + 6, py + 6] = color
      image[px + 7, py + 4] = color
    end

    def draw_ballot_x(image, px, py, fg_rgb)
      color = ChunkyPNG::Color.rgb(*fg_rgb)
      image[px + 2, py + 5] = color
      image[px + 3, py + 6] = color
      image[px + 3, py + 7] = color
      image[px + 4, py + 8] = color
      image[px + 5, py + 9] = color
      image[px + 5, py + 10] = color
      image[px + 6, py + 11] = color
      image[px + 2, py + 11] = color
      image[px + 3, py + 10] = color
      image[px + 3, py + 9] = color
      image[px + 5, py + 7] = color
      image[px + 5, py + 6] = color
      image[px + 6, py + 5] = color
    end

    def draw_up_arrow(image, px, py, fg_rgb)
      color = ChunkyPNG::Color.rgb(*fg_rgb)
      (3..12).each { |dy| image[px + 4, py + dy] = color }
      image[px + 3, py + 4] = color
      image[px + 5, py + 4] = color
      image[px + 2, py + 5] = color
      image[px + 6, py + 5] = color
    end

    def draw_down_arrow(image, px, py, fg_rgb)
      color = ChunkyPNG::Color.rgb(*fg_rgb)
      (3..12).each { |dy| image[px + 4, py + dy] = color }
      image[px + 3, py + 11] = color
      image[px + 5, py + 11] = color
      image[px + 2, py + 10] = color
      image[px + 6, py + 10] = color
    end

    def draw_right_arrow(image, px, py, fg_rgb)
      color = ChunkyPNG::Color.rgb(*fg_rgb)
      (1..6).each { |dx| image[px + dx, py + 8] = color }
      image[px + 5, py + 7] = color
      image[px + 5, py + 9] = color
      image[px + 4, py + 6] = color
      image[px + 4, py + 10] = color
    end

    def draw_gear(image, px, py, fg_rgb)
      color = ChunkyPNG::Color.rgb(*fg_rgb)
      image[px + 4, py + 6] = color
      image[px + 4, py + 10] = color
      image[px + 2, py + 8] = color
      image[px + 6, py + 8] = color
      image[px + 3, py + 7] = color
      image[px + 5, py + 7] = color
      image[px + 3, py + 9] = color
      image[px + 5, py + 9] = color
      image[px + 4, py + 5] = color
      image[px + 4, py + 11] = color
      image[px + 1, py + 8] = color
      image[px + 7, py + 8] = color
      image[px + 2, py + 6] = color
      image[px + 6, py + 6] = color
      image[px + 2, py + 10] = color
      image[px + 6, py + 10] = color
    end

    def draw_warning(image, px, py, fg_rgb)
      color = ChunkyPNG::Color.rgb(*fg_rgb)
      image[px + 4, py + 3] = color
      image[px + 3, py + 4] = color
      image[px + 5, py + 4] = color
      image[px + 3, py + 5] = color
      image[px + 5, py + 5] = color
      image[px + 2, py + 6] = color
      image[px + 6, py + 6] = color
      image[px + 2, py + 7] = color
      image[px + 6, py + 7] = color
      image[px + 1, py + 8] = color
      image[px + 7, py + 8] = color
      image[px + 1, py + 9] = color
      image[px + 7, py + 9] = color
      (1..7).each { |dx| image[px + dx, py + 10] = color }
      image[px + 4, py + 5] = color
      image[px + 4, py + 6] = color
      image[px + 4, py + 7] = color
      image[px + 4, py + 9] = color
    end

    def draw_ellipsis(image, px, py, fg_rgb)
      color = ChunkyPNG::Color.rgb(*fg_rgb)
      image[px + 1, py + 12] = color
      image[px + 4, py + 12] = color
      image[px + 6, py + 12] = color
    end

    def draw_left_arrow(image, px, py, fg_rgb)
      color = ChunkyPNG::Color.rgb(*fg_rgb)
      (1..6).each { |dx| image[px + dx, py + 8] = color }
      image[px + 2, py + 7] = color
      image[px + 2, py + 9] = color
      image[px + 3, py + 6] = color
      image[px + 3, py + 10] = color
    end

    def draw_left_half_block(image, px, py, fg_rgb)
      fill_rect(image, px, py, 4, CELL_H, fg_rgb)
    end

    def draw_right_half_block(image, px, py, fg_rgb)
      fill_rect(image, px + 4, py, 4, CELL_H, fg_rgb)
    end

    def draw_checkbox_border(image, px, py, color)
      (1..6).each do |dx|
        image[px + dx, py + 4] = color
        image[px + dx, py + 11] = color
      end
      (4..11).each do |dy|
        image[px + 1, py + dy] = color
        image[px + 6, py + dy] = color
      end
    end

    def draw_empty_checkbox(image, px, py, fg_rgb)
      color = ChunkyPNG::Color.rgb(*fg_rgb)
      draw_checkbox_border(image, px, py, color)
    end

    def draw_checked_checkbox(image, px, py, fg_rgb)
      color = ChunkyPNG::Color.rgb(*fg_rgb)
      draw_checkbox_border(image, px, py, color)
      image[px + 2, py + 8] = color
      image[px + 3, py + 9] = color
      image[px + 4, py + 7] = color
      image[px + 5, py + 5] = color
    end

    def draw_x_checkbox(image, px, py, fg_rgb)
      color = ChunkyPNG::Color.rgb(*fg_rgb)
      draw_checkbox_border(image, px, py, color)
      image[px + 2, py + 5] = color
      image[px + 2, py + 6] = color
      image[px + 3, py + 7] = color
      image[px + 3, py + 8] = color
      image[px + 4, py + 7] = color
      image[px + 4, py + 8] = color
      image[px + 5, py + 9] = color
      image[px + 5, py + 10] = color
      image[px + 2, py + 10] = color
      image[px + 2, py + 9] = color
      image[px + 5, py + 6] = color
      image[px + 5, py + 5] = color
    end

    def draw_info_symbol(image, px, py, fg_rgb)
      color = ChunkyPNG::Color.rgb(*fg_rgb)
      (3..5).each do |dx|
        image[px + dx, py + 4] = color
        image[px + dx, py + 12] = color
      end
      image[px + 2, py + 5] = color
      image[px + 6, py + 5] = color
      image[px + 2, py + 11] = color
      image[px + 6, py + 11] = color
      (6..10).each do |dy|
        image[px + 1, py + dy] = color
        image[px + 7, py + dy] = color
      end
      image[px + 4, py + 6] = color
      (8..10).each do |dy|
        image[px + 4, py + dy] = color
      end
    end

    def draw_heavy_x(image, px, py, fg_rgb)
      color = ChunkyPNG::Color.rgb(*fg_rgb)
      [4, 5, 11, 12].each do |dy|
        image[px + 1, py + dy] = color
        image[px + 2, py + dy] = color
        image[px + 5, py + dy] = color
        image[px + 6, py + dy] = color
      end
      [6, 7, 9, 10].each do |dy|
        image[px + 2, py + dy] = color
        image[px + 3, py + dy] = color
        image[px + 4, py + dy] = color
        image[px + 5, py + dy] = color
      end
      image[px + 3, py + 8] = color
      image[px + 4, py + 8] = color
    end

  end
end
