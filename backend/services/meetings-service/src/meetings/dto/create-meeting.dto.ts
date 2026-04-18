import {
  IsDateString,
  IsEnum,
  IsNotEmpty,
  IsOptional,
  IsString,
  IsUrl,
} from 'class-validator';
import { MeetingPlatform } from '../meeting.schema';

export class CreateMeetingDto {
  @IsString()
  @IsNotEmpty()
  title!: string;

  @IsEnum(MeetingPlatform)
  platform!: MeetingPlatform;

  @IsUrl()
  link!: string;

  @IsOptional()
  @IsString()
  meetingId?: string;

  @IsOptional()
  @IsString()
  passcode?: string;

  @IsDateString()
  scheduledAt!: string;

  @IsOptional()
  @IsString()
  notes?: string;
}
