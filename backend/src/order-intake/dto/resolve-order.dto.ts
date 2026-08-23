import { Type } from 'class-transformer';
import {
  IsArray,
  IsBoolean,
  IsIn,
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  MaxLength,
  Min,
  ValidateNested,
} from 'class-validator';

export class ResolveOrderItemDto {
  @IsString()
  @MaxLength(500)
  rawText: string;

  @IsString()
  @MaxLength(160)
  rawProductName: string;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  quantity: number | null;

  @IsOptional()
  @IsString()
  @MaxLength(40)
  unit: string | null;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  unitPrice?: number | null;

  @IsOptional()
  @IsString()
  @MaxLength(300)
  note: string | null;

  @IsBoolean()
  needsReview: boolean;

  @IsOptional()
  @IsString()
  @MaxLength(300)
  uncertaintyReason: string | null;

  @IsOptional()
  @IsString()
  selectedProductId?: string;
}

export class ResolveOrderDto {
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => ResolveOrderItemDto)
  items: ResolveOrderItemDto[];

  @IsIn(['good', 'readable', 'poor'])
  imageQuality: 'good' | 'readable' | 'poor';

  @IsOptional()
  @IsString()
  @MaxLength(500)
  generalNote: string | null;
}
